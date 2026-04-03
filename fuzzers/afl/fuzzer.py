# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Integration code for AFL fuzzer."""

import json
import os
import shutil
import subprocess
import threading  # [新增]
import time       # [新增]
import sys        # [新增]

from fuzzers import utils


def prepare_build_environment():
    """Set environment variables used to build targets for AFL-based
    fuzzers."""
    cflags = ['-fsanitize-coverage=trace-pc-guard']
    utils.append_flags('CFLAGS', cflags)
    utils.append_flags('CXXFLAGS', cflags)

    os.environ['CC'] = 'clang'
    os.environ['CXX'] = 'clang++'
    os.environ['FUZZER_LIB'] = '/libAFL.a'


def build():
    """Build benchmark."""
    prepare_build_environment()

    utils.build_benchmark()

    print('[post_build] Copying afl-fuzz to $OUT directory')
    # Copy out the afl-fuzz binary as a build artifact.
    shutil.copy('/afl/afl-fuzz', os.environ['OUT'])


def get_stats(output_corpus, fuzzer_log):  # pylint: disable=unused-argument
    """Gets fuzzer stats for AFL."""
    # Get a dictionary containing the stats AFL reports.
    stats_file = os.path.join(output_corpus, 'fuzzer_stats')
    if not os.path.exists(stats_file):
        print('Can\'t find fuzzer_stats')
        return '{}'
    with open(stats_file, encoding='utf-8') as file_handle:
        stats_file_lines = file_handle.read().splitlines()
    stats_file_dict = {}
    for stats_line in stats_file_lines:
        key, value = stats_line.split(': ')
        stats_file_dict[key.strip()] = value.strip()

    # Report to FuzzBench the stats it accepts.
    stats = {'execs_per_sec': float(stats_file_dict['execs_per_sec'])}
    return json.dumps(stats)


def prepare_fuzz_environment(input_corpus):
    """Prepare to fuzz with AFL or another AFL-based fuzzer."""
    # Tell AFL to not use its terminal UI so we get usable logs.
    os.environ['AFL_NO_UI'] = '1'
    # Skip AFL's CPU frequency check (fails on Docker).
    os.environ['AFL_SKIP_CPUFREQ'] = '1'
    # No need to bind affinity to one core, Docker enforces 1 core usage.
    os.environ['AFL_NO_AFFINITY'] = '1'
    # AFL will abort on startup if the core pattern sends notifications to
    # external programs. We don't care about this.
    os.environ['AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES'] = '1'
    # Don't exit when crashes are found. This can happen when corpus from
    # OSS-Fuzz is used.
    os.environ['AFL_SKIP_CRASHES'] = '1'
    # Shuffle the queue
    os.environ['AFL_SHUFFLE_QUEUE'] = '1'

    # AFL needs at least one non-empty seed to start.
    utils.create_seed_file_for_empty_corpus(input_corpus)


def check_skip_det_compatible(additional_flags):
    """ Checks if additional flags are compatible with '-d' option"""
    # AFL refuses to take in '-d' with '-M' or '-S' options for parallel mode.
    # (cf. https://github.com/google/AFL/blob/8da80951/afl-fuzz.c#L7477)
    if '-M' in additional_flags or '-S' in additional_flags:
        return False
    return True


# [新增] 专门用于后台同步 stats 到 CSV 的函数
def stats_to_csv_syncer(src_path, dst_path):
    """
    每分钟读取 AFL fuzzer_stats，解析并追加到 CSV 文件中。
    """
    print(f'[StatsSyncer] Monitoring {src_path} -> CSV: {dst_path}')
    sys.stdout.flush()
    
    # 确保目标目录存在
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    
    while True:
        try:
            if os.path.exists(src_path):
                # 1. 读取 AFL 原始统计文件
                stats_data = {}
                stats_data['timestamp'] = str(int(time.time())) # 添加当前时间戳
                
                with open(src_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if ':' in line:
                            key, value = line.split(':', 1)
                            stats_data[key.strip()] = value.strip()
                
                # 2. 写入 CSV
                file_exists = os.path.exists(dst_path)
                
                with open(dst_path, 'a') as f_csv:
                    # 如果是新文件，先写入表头 (Keys)
                    if not file_exists or os.path.getsize(dst_path) == 0:
                        header = ",".join(stats_data.keys())
                        f_csv.write(header + "\n")
                    
                    # 写入数据行 (Values)
                    # 注意：我们要确保 Values 的顺序与 Keys 的顺序一致
                    # Python 3.7+ 字典保持插入顺序，但为了健壮性，建议基于 keys 读值
                    # 这里为了代码简洁，直接使用 values (只要 AFL 输出顺序不变即可)
                    values = ",".join(str(v) for v in stats_data.values())
                    f_csv.write(values + "\n")
                    
        except Exception as e:
            print(f'[StatsSyncer] Error: {e}')
        
        # 每 60 秒同步一次
        time.sleep(60)

# [关键修复] 告诉 FuzzBench 真正的语料保存在哪里
def get_sync_dir(output_corpus):
    """Returns the sync dir for the fuzzer."""
    return os.path.join(output_corpus, 'queue')
    
def run_afl_fuzz(input_corpus,
                 output_corpus,
                 target_binary,
                 additional_flags=None,
                 hide_output=False):
    """Run afl-fuzz."""
    # Spawn the afl fuzzing process.
    print('[run_afl_fuzz] Running target with afl-fuzz')

    # [新增] 启动 Stats CSV Dumper 线程
    # 源文件: AFL 输出目录下的 fuzzer_stats
    stats_src = os.path.join(output_corpus, 'fuzzer_stats')
    # 目标文件: 输出目录的上一级 (通常是 /out/) 下的 fuzzer_stats_history.csv
    # 这样可以避免污染 corpus 目录，同时也能被 FuzzBench 保存
    stats_dst = '/out/results/fuzzer_stats_history.csv'
    
    stats_thread = threading.Thread(target=stats_to_csv_syncer, args=(stats_src, stats_dst))
    stats_thread.daemon = True # 设置为守护线程，主进程退出它也会退出
    stats_thread.start()
    # ---------------------------------------------------------

    command = [
        './afl-fuzz',
        '-i',
        input_corpus,
        '-o',
        output_corpus,
        # Use no memory limit as ASAN doesn't play nicely with one.
        '-m',
        'none',
        '-t',
        '1000+',  # Use same default 1 sec timeout, but add '+' to skip hangs.
    ]
    # Use '-d' to skip deterministic mode, as long as it it compatible with
    # additional flags.
    if not additional_flags or check_skip_det_compatible(additional_flags):
        command.append('-d')
    if additional_flags:
        command.extend(additional_flags)
    dictionary_path = utils.get_dictionary_path(target_binary)
    if dictionary_path:
        command.extend(['-x', dictionary_path])
    command += [
        '--',
        target_binary,
        # Pass INT_MAX to afl the maximize the number of persistent loops it
        # performs.
        '2147483647'
    ]
    print('[run_afl_fuzz] Running command: ' + ' '.join(command))
    output_stream = subprocess.DEVNULL if hide_output else None
    subprocess.check_call(command, stdout=output_stream, stderr=output_stream)


def fuzz(input_corpus, output_corpus, target_binary):
    """Run afl-fuzz on target."""
    prepare_fuzz_environment(input_corpus)

    run_afl_fuzz(input_corpus, output_corpus, target_binary)
