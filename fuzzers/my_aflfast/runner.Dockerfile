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
# 1. 基础依赖 (绝对直连模式)
# ==========================================
# 【核心修复】：强行清除前置环境可能渗透进来的代理，完全直连清华源，避开 502
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    libc++1 \
    libc++abi1 && \
    rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 恢复全局运行时代理与白名单
# ==========================================
# apt-get 安全跑完后，再把代理加回来
# 保障容器在正式跑实验时，FuzzBench 的 Python 脚本如果需要联网上报状态，可以顺利翻墙
ENV http_proxy=http://172.17.0.1:7897 \
    https_proxy=http://172.17.0.1:7897 \
    no_proxy="localhost,127.0.0.1,.tsinghua.edu.cn,.aliyun.com"
