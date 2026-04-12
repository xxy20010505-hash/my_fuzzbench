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
# 1. 基础依赖 (替换国内镜像源，修复 502 Bad Gateway)
# ==========================================
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 核心修复：一键替换 Ubuntu 默认源为清华大学镜像源，并加上 --fix-missing 提高容错率
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
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
# 2. 拉取源码 (清理了重复克隆，修复子模块超时)
# ==========================================
# 配置 Git 代理与网络优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# 克隆主仓库并立即拉取子模块
RUN git clone https://github.com/freetype/freetype.git freetype2 && \
    cd freetype2 && \
    git submodule update --init --recursive

# 拉取测试用例
RUN git clone https://github.com/unicode-org/text-rendering-tests.git TRT

# 拉取依赖库
RUN wget https://github.com/libarchive/libarchive/releases/download/v3.4.3/libarchive-3.4.3.tar.xz

# 加入国内镜像源兜底，防止后续 build.sh 中的 git 操作超时
RUN git config --global url."https://kkgithub.com/".insteadOf "https://github.com/"

# 清理配置 (保留 url.insteadOf 作为护身符)
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
