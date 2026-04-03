from fuzzers.afl import fuzzer as afl_fuzzer
import os       # [新增]
import threading # [新增]
import time     # [新增]
import sys      # [新增]


def build():
    """Build benchmark."""
    afl_fuzzer.build()


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
    
def fuzz(input_corpus, output_corpus, target_binary):
    """Run fuzzer."""
    afl_fuzzer.prepare_fuzz_environment(input_corpus)

    # === [新增] 启动 Stats CSV Dumper 线程 ===
    # 源文件: AFL 输出目录下的 fuzzer_stats
    stats_src = os.path.join(output_corpus, 'fuzzer_stats')
    # 目标文件: 输出目录的上一级 (通常是 /out/) 下的 fuzzer_stats_history.csv
    stats_dst = '/out/results/fuzzer_stats_history.csv'
    
    stats_thread = threading.Thread(target=stats_to_csv_syncer, args=(stats_src, stats_dst))
    stats_thread.daemon = True # 守护线程，主程序退出它也会退出
    stats_thread.start()
    # ==========================================

    # Write AFL's output to /dev/null to avoid filling up disk by writing too
    # much to log file. This is a problem in general with AFLFast but
    # particularly with the lcms benchmark.
    afl_fuzzer.run_afl_fuzz(input_corpus,
                            output_corpus,
                            target_binary,
                            hide_output=True)
