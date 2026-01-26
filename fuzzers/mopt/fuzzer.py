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
"""Integration code for MOpt fuzzer."""

import os
import shutil
from fuzzers.afl import fuzzer as afl_fuzzer

def build():
    """Build benchmark."""
    # 1. 调用 AFL 的标准构建过程
    afl_fuzzer.build()
    
    # 2. 【核心修复】将编译好的 afl-fuzz 复制到 /out 目录
    # FuzzBench 会自动将 /out 目录的内容打包到 Runner 镜像中
    src = '/afl/afl-fuzz'
    dst = os.path.join(os.environ['OUT'], 'afl-fuzz')
    
    print(f"Copying {src} to {dst}...")
    shutil.copy(src, dst)
    # 顺便把权限也设好
    os.chmod(dst, 0o755)

def fuzz(input_corpus, output_corpus, target_binary):
    """Run fuzzer."""
    afl_fuzzer.prepare_fuzz_environment(input_corpus)

    # 3. 【核心修复】告诉 FuzzBench 去 /out 目录找二进制文件
    # 在 Runner 镜像里，/out 目录会被挂载，所以路径是正确的
    binary_path = os.path.join(os.environ['OUT'], 'afl-fuzz')

    afl_fuzzer.run_afl_fuzz(
        input_corpus,
        output_corpus,
        target_binary,
        fuzzer_path=binary_path, # 指向 /out/afl-fuzz
        additional_flags=[
            '-L',
            '0',
        ])
