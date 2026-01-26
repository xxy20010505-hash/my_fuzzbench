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

FROM gcr.io/fuzzbench/base-image

# ==========================================
# 1. 补全运行时依赖 (吸取之前的教训)
# ==========================================
# libglib2.0-0: AFL++ 核心依赖
# libpixman-1-0: AFL++ 常用依赖
# libc++1: 兼容 Clang 编译出的目标程序
RUN http_proxy=http://192.168.21.1:7890 https_proxy=http://192.168.21.1:7890 \
    apt-get update && \
    apt-get install -y \
    libglib2.0-0 \
    libpixman-1-0 \
    libc++1 \
    libpython3.8 \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 保留原版的优化配置 (直接复制过来的)
# ==========================================
# 将 /out 加入路径，方便直接调用
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/out"
ENV PATH="$PATH:/out"

# AFL++ 运行时配置
ENV AFL_SKIP_CPUFREQ=1
ENV AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
ENV AFL_TESTCACHE_SIZE=2
# 建议加一个: 显式告诉 AFL++ 不需要 Python 模式 (除非你用了高级功能)
ENV AFL_NO_PYTHON=1
