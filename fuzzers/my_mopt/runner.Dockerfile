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
# 优化版：换源 + 代理 + 安装依赖
# ==========================================
# 1. 配置 APT 代理 (写入配置文件比 ENV 更稳定)
# 2. 替换为阿里云源 (解决 502 Bad Gateway 问题)
# 3. 安装依赖 (保留了你原来的列表)
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7897";' > /etc/apt/apt.conf.d/99proxy && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7897";' >> /etc/apt/apt.conf.d/99proxy && \
    #sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    #sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libstdc++6 \
    libc++1 \
    libc++abi1 && \
    # 安装完后清理代理配置和缓存，减小镜像体积
    rm /etc/apt/apt.conf.d/99proxy && \
    rm -rf /var/lib/apt/lists/*
