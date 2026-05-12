import os
import shutil
import subprocess
import sys
import time
import threading
import socket
import traceback
from fuzzers import utils

# === [关键修复] 告诉 FuzzBench 真正的语料保存在哪里 ===
def get_sync_dir(output_corpus):
    """Returns the sync dir for the fuzzer."""
    return os.path.join(output_corpus, 'queue')

def build():
    # --- 1. 编译环境设置 ---
    os.environ['CC'] = '/usr/bin/afl-clang-fast'
    os.environ['CXX'] = '/usr/bin/afl-clang-fast++'
    os.environ['FUZZER_LIB'] = '/libAFL.a'

    # --- 2. 智能源码目录适配 ---
    utils.build_benchmark()

    print('[post_build] Copying afl-fuzz to $OUT directory', flush=True)
    
    src_fuzz = '/usr/local/bin/afl-fuzz'
    if not os.path.exists(src_fuzz):
        src_fuzz = '/usr/bin/fuzz'
    
    if os.path.exists(src_fuzz):
        shutil.copy(src_fuzz, os.path.join(os.environ['OUT'], 'afl-fuzz'))

def wait_for_redis(host='127.0.0.1', port=6379, timeout=10):
    """循环检查 Redis 端口是否已打开"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            if sock.connect_ex((host, port)) == 0:
                print('[prepare] Redis is ready!', flush=True)
                return True
        time.sleep(0.5)
        print('[prepare] Waiting for Redis...', flush=True)
    return False

def prepare_fuzz_environment(input_corpus):
    # --- 环境变量 ---
    os.environ['AFL_NO_UI'] = '1'
    os.environ['AFL_SKIP_CPUFREQ'] = '1'
    os.environ['AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES'] = '1'
    os.environ['AFL_SKIP_CRASHES'] = '1'
    os.environ['AFL_SHUFFLE_QUEUE'] = '1'
    
    # 注入 ONNX Runtime 库路径
    ld_path = os.environ.get('LD_LIBRARY_PATH', '')
    if '/opt/onnxruntime/lib' not in ld_path:
        os.environ['LD_LIBRARY_PATH'] = f"/opt/onnxruntime/lib:{ld_path}"

    print('[prepare] Starting Redis...', flush=True)
    
    try:
        # 禁用 Redis 持久化，防止 24 小时实验占满磁盘 IO
        subprocess.Popen([
            'redis-server', 
            '--daemonize', 'yes',
            '--save', '',        # 禁用 RDB 快照
            '--appendonly', 'no' # 禁用 AOF 日志
        ])
    except FileNotFoundError:
        print("ERROR: 'redis-server' not found. Did you install it in Dockerfile?", flush=True)
        raise

    if not wait_for_redis():
        print("ERROR: Redis failed to start within timeout!", flush=True)

    utils.create_seed_file_for_empty_corpus(input_corpus)

# === CSV 格式统计信息同步线程 ===
def stats_to_csv_syncer(src_path, dst_path):
    """每分钟读取 AFL fuzzer_stats，解析并追加到 CSV 文件中。"""
    print(f'[StatsSyncer] Monitoring {src_path} -> CSV: {dst_path}', flush=True)
    
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    
    while True:
        try:
            if os.path.exists(src_path):
                stats_data = {'timestamp': str(int(time.time()))}
                
                with open(src_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if ':' in line:
                            key, value = line.split(':', 1)
                            stats_data[key.strip()] = value.strip()
                
                file_exists = os.path.exists(dst_path)
                with open(dst_path, 'a') as f_csv:
                    if not file_exists or os.path.getsize(dst_path) == 0:
                        header = ",".join(stats_data.keys())
                        f_csv.write(header + "\n")
                    
                    values = ",".join(str(v) for v in stats_data.values())
                    f_csv.write(values + "\n")
                    
        except Exception as e:
            print(f'[StatsSyncer] Error: {e}', flush=True)
        
        time.sleep(60)

def run_afl_fuzz(input_corpus, output_corpus, target_binary, additional_flags=None, hide_output=False):
    try:
        print('[run_afl_fuzz] Preparing...', flush=True)

        # 1. 检查 AFL 二进制
        afl_fuzz_path = os.path.join(os.environ['OUT'], 'afl-fuzz')
        if not os.path.exists(afl_fuzz_path):
             print(f"FATAL ERROR: AFL binary not found at {afl_fuzz_path}", flush=True)
             return
        
        os.chmod(afl_fuzz_path, 0o755)

        # 2. 检查种子目录
        if os.path.exists(input_corpus):
            if len(os.listdir(input_corpus)) == 0:
                print("WARNING: Input corpus is EMPTY! AFL will exit immediately.", flush=True)
        else:
            print(f"FATAL ERROR: Input corpus directory does not exist!", flush=True)

        # 3. 启动 Stats CSV Dumper 线程
        stats_src = os.path.join(output_corpus, 'fuzzer_stats')
        stats_dst = '/out/results/fuzzer_stats_history.csv'
        
        stats_thread = threading.Thread(target=stats_to_csv_syncer, args=(stats_src, stats_dst))
        stats_thread.daemon = True
        stats_thread.start()

        # 4. 构建命令 (直接指向 output_corpus)
        command = [
            afl_fuzz_path,
            '-i', input_corpus,
            '-o', output_corpus,
            '-m', 'none',
            '-t', '2000+', # Timeout 2000ms
            '-d'
        ]

        if additional_flags:
            command.extend(additional_flags)

        dictionary_path = utils.get_dictionary_path(target_binary)
        if dictionary_path:
            command.extend(['-x', dictionary_path])

        command += ['--', target_binary, '@@']

        # 5. 打印并执行
        cmd_str = ' '.join(command)
        print(f'[run_afl_fuzz] EXEC CMD: {cmd_str}', flush=True)
        print(f'[run_afl_fuzz] AFL starting... Logs are streaming to stdout.', flush=True)

        process = subprocess.Popen(
            command, 
            stdout=sys.stdout, 
            stderr=sys.stderr,
        )
        
        # 依赖 process.wait() 阻塞主线程。FuzzBench 结束时会终止这个进程，脚本完美退出。
        ret_code = process.wait()
        print(f'[run_afl_fuzz] AFL exited with code: {ret_code}', flush=True)

    except Exception as e:
        print(f'[run_afl_fuzz] EXCEPTION CAUGHT: {e}', flush=True)
        traceback.print_exc()

def fuzz(input_corpus, output_corpus, target_binary):
    prepare_fuzz_environment(input_corpus)
    run_afl_fuzz(input_corpus, output_corpus, target_binary)
