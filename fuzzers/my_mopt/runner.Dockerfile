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
# 0. 设置全局构建代理与白名单（双轨分流核心）
# ==========================================
# Git, wget 自动走 172 代理；清华源、本地网络直连
ENV http_proxy=http://172.17.0.1:7897 \
    https_proxy=http://172.17.0.1:7897 \
    no_proxy="localhost,127.0.0.1,.tsinghua.edu.cn"

# ==========================================
# 1. 优化版：清华源直连 + 安装依赖
# ==========================================
# 彻底移除旧版 proxy.conf，改为替换清华源直连，享受物理机满速
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libstdc++6 \
    libc++1 \
    libc++abi1 && \
    # 清理缓存，减小镜像体积
    rm -rf /var/lib/apt/lists/*
