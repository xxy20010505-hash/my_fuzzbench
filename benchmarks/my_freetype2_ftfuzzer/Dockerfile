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
# 【核心修复】：强行清除可能渗透进来的代理，直连阿里云镜像源，完美避开 502
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --fix-missing \
    make \
    autoconf \
    automake \
    libtool \
    wget \
    pkg-config \
    zlib1g-dev \
    libpng-dev \
    libbz2-dev

# ==========================================
# 2. 开启全局代理 & 拉取源码
# ==========================================
# apt 安装完毕后，再将代理注入环境，供后面的 Git 和 wget 翻墙使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 配置 Git 代理与网络大文件优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# 克隆主仓库并立即拉取子模块 (保留完整历史，防止 checkout 报错)
RUN git clone https://github.com/freetype/freetype.git freetype2 && \
    cd freetype2 && \
    git submodule update --init --recursive

# 拉取测试用例
RUN git clone https://github.com/unicode-org/text-rendering-tests.git TRT

# 拉取依赖库 (wget 会自动走上面设置的 ENV 代理)
RUN wget https://github.com/libarchive/libarchive/releases/download/v3.4.3/libarchive-3.4.3.tar.xz

# 恢复 Git 默认配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 3. 复制构建脚本
# ==========================================
COPY * $SRC/

# ==========================================
# 4. 清理环境变量
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
