# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder@sha256:87ca1e9e19235e731fac8de8d1892ebe8d55caf18e7aa131346fc582a2034fdd

# ==========================================
# 1. 基础依赖 (绝对直连模式)
# ==========================================
# 【核心修复】：移除顶层代理，强行 unset 保证 apt-get 纯净直连阿里云
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --fix-missing \
    autoconf \
    automake \
    make \
    wget \
    libtool \
    pkg-config

# ==========================================
# 2. 开启全局代理 & 拉取源码
# ==========================================
# apt 跑完后注入代理 (统一使用 172.17.0.1:7897)
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# 【关键保留】全量克隆并回退到 2023-06-01，保证 Makefile 逻辑跑通
RUN git clone https://github.com/google/re2.git && \
    cd re2 && \
    git checkout 2023-06-01

RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 3. 注入资源
# ==========================================
# 保持原版逻辑：字典下载到 $OUT
RUN wget --no-check-certificate -qO $OUT/fuzzer.dict \
    https://raw.githubusercontent.com/google/fuzzing/master/dictionaries/regexp.dict

# 保持原版逻辑：文件复制到 $SRC (OSS-Fuzz 规范)
COPY build.sh target.cc $SRC/
RUN chmod +x $SRC/build.sh

# ==========================================
# 4. 清理环境变量
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
