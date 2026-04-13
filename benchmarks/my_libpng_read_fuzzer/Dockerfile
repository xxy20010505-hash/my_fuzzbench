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
# 1. 基础环境
# ==========================================
# 【修正】统一使用 7897 端口，确保全局代理生效
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 换源 + 安装依赖
# 【核心修复 1】彻底移除 99proxy 强制代理，让 apt 直连阿里云镜像源
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --fix-missing \
    make autoconf automake libtool zlib1g-dev pkg-config \
    zip

# ==========================================
# 2. 准备源码
# ==========================================
# 配置 Git 代理与优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# (A) 克隆 Zlib (带版本号分支，使用 depth 1 是安全的)
RUN git clone --depth 1 --branch v1.2.13 https://github.com/madler/zlib.git $SRC/zlib

# (B) 克隆 Libpng 
# 【核心修复 2】移除 --depth 1，保留完整历史，防止 FuzzBench 回退代码时失败
RUN git clone https://github.com/glennrp/libpng.git $SRC/libpng

# 恢复 Git 配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 3. 注入构建脚本
# ==========================================
WORKDIR $SRC/libpng

# 复制我们在 Step 1 创建的 build.sh
COPY build.sh $SRC/build.sh
RUN chmod +x $SRC/build.sh

# ==========================================
# 4. 字典与清理
# ==========================================
# 顶部的 ENV 代理在这里会起作用，确保能连上 raw.githubusercontent.com
RUN wget --no-check-certificate -qO $SRC/libpng_read_fuzzer.dict \
    https://raw.githubusercontent.com/google/fuzzing/master/dictionaries/png.dict

ADD seeds /opt/seeds
COPY * $SRC/

# ==========================================
# 5. 清理
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
