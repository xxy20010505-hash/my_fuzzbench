import os
import shutil
import subprocess
import sys
import time
import threading
import socket
import traceback
from fuzzers import utils

def build():
    # --- 1. 编译环境设置 ---
    os.environ['CC'] = '/usr/bin/afl-clang-fast'
    os.environ['CXX'] = '/usr/bin/afl-clang-fast++'
    os.environ['FUZZER_LIB'] = '/libAFL.a'

    # --- 2. 智能源码目录适配 ---
    utils.build_benchmark()

    print('[post_build] Copying afl-fuzz to $OUT directory')
    sys.stdout.flush()
    
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
                print('[prepare] Redis is ready!')
                sys.stdout.flush()
                return True
        time.sleep(0.5)
        print('[prepare] Waiting for Redis...')
        sys.stdout.flush()
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

    print('[prepare] Starting Redis...')
    sys.stdout.flush()
    
    try:
        # [修改] 禁用 Redis 持久化，防止 24 小时实验占满磁盘 IO
        subprocess.Popen([
            'redis-server', 
            '--daemonize', 'yes',
            '--save', '',        # 禁用 RDB 快照
            '--appendonly', 'no' # 禁用 AOF 日志
        ])
    except FileNotFoundError:
        print("ERROR: 'redis-server' not found. Did you install it in Dockerfile?")
        sys.stdout.flush()
        raise

    if not wait_for_redis():
        print("ERROR: Redis failed to start within timeout!")
        sys.stdout.flush()

    utils.create_seed_file_for_empty_corpus(input_corpus)

# === [新增] CSV 格式统计信息同步线程 ===
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
                    # 只要 Python 版本 >= 3.7，字典顺序是插入顺序，通常没问题
                    # 但为了保险，我们最好重新读一遍 header (这里简化处理，假设顺序不变)
                    values = ",".join(str(v) for v in stats_data.values())
                    f_csv.write(values + "\n")
                    
        except Exception as e:
            print(f'[StatsSyncer] Error: {e}')
        
        # 每 60 秒同步一次
        time.sleep(60)

def sync_corpus(src_dir, dst_dir):
    """后台搬运线程"""
    print(f'[Syncer] Started syncing {src_dir} -> {dst_dir}')
    sys.stdout.flush()
    
    os.makedirs(dst_dir, exist_ok=True)
    seen_files = set()
    
    while True:
        try:
            if os.path.exists(src_dir):
                for root, dirs, files in os.walk(src_dir):
                    for f in files:
                        if f not in seen_files and not f.startswith('.'):
                            s = os.path.join(root, f)
                            d = os.path.join(dst_dir, f)
                            if os.path.isfile(s) and os.path.getsize(s) > 0:
                                try:
                                    shutil.copy2(s, d)
                                    seen_files.add(f)
                                except Exception:
                                    pass
        except Exception as e:
            print(f'[Syncer] Error: {e}')
            sys.stdout.flush()
        
        time.sleep(5) 

def run_afl_fuzz(input_corpus, output_corpus, target_binary, additional_flags=None, hide_output=False):
    try:
        print('[run_afl_fuzz] Preparing...')
        sys.stdout.flush()

        # 1. 检查 AFL 二进制
        afl_fuzz_path = os.path.join(os.environ['OUT'], 'afl-fuzz')
        if not os.path.exists(afl_fuzz_path):
             print(f"FATAL ERROR: AFL binary not found at {afl_fuzz_path}")
             sys.stdout.flush()
             return
        
        os.chmod(afl_fuzz_path, 0o755)

        # 2. 检查种子目录
        print(f"[DEBUG] Checking input corpus at: {input_corpus}")
        if os.path.exists(input_corpus):
            files = os.listdir(input_corpus)
            if len(files) == 0:
                print("WARNING: Input corpus is EMPTY! AFL will exit immediately.")
        else:
            print(f"FATAL ERROR: Input corpus directory does not exist!")
        sys.stdout.flush()

        # 3. 准备工作目录
        afl_work_dir = '/out/afl_work'
        if os.path.exists(afl_work_dir):
            shutil.rmtree(afl_work_dir)
        os.makedirs(afl_work_dir)

        # 启动 Corpus Sync 线程
        sync_thread = threading.Thread(target=sync_corpus, args=(afl_work_dir, output_corpus))
        sync_thread.daemon = True
        sync_thread.start()

        # === [新增] 启动 Stats CSV Dumper 线程 ===
        # 源文件: AFL 生成的 stats
        stats_src = os.path.join(afl_work_dir, 'fuzzer_stats')
        # 目标文件: FuzzBench 结果目录下的 CSV 文件
        stats_dst = '/out/results/fuzzer_stats_history.csv'
        
        stats_thread = threading.Thread(target=stats_to_csv_syncer, args=(stats_src, stats_dst))
        stats_thread.daemon = True
        stats_thread.start()
        # ==========================================

        # 4. 构建命令
        command = [
            afl_fuzz_path,
            '-i', input_corpus,
            '-o', afl_work_dir,
            '-m', 'none',
            '-t', '2000', # Timeout 2000ms
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
        print(f'[run_afl_fuzz] EXEC CMD: {cmd_str}')
        print(f'[run_afl_fuzz] AFL starting... Logs are streaming to stdout.')
        sys.stdout.flush()

        process = subprocess.Popen(
            command, 
            stdout=sys.stdout, 
            stderr=sys.stderr,
        )
        
        ret_code = process.wait()
        print(f'[run_afl_fuzz] AFL exited with code: {ret_code}')
        sys.stdout.flush()

        if ret_code != 0:
            print("FATAL: AFL exited abnormally.")
            sys.stdout.flush()

    except Exception as e:
        print(f'[run_afl_fuzz] EXCEPTION CAUGHT: {e}')
        traceback.print_exc()
        sys.stdout.flush()

    # --- 死循环保活 ---
    print('[run_afl_fuzz] Entering infinite sleep loop to keep container alive...')
    sys.stdout.flush()
    while True:
        time.sleep(60)

def fuzz(input_corpus, output_corpus, target_binary):
    prepare_fuzz_environment(input_corpus)
    run_afl_fuzz(input_corpus, output_corpus, target_binary)
