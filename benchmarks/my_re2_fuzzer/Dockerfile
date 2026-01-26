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
# 1. 网络配置 (只加代理和换源)
# ==========================================
ENV http_proxy=http://192.168.21.1:7890
ENV https_proxy=http://192.168.21.1:7890

# 换阿里云源
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7890";' > /etc/apt/apt.conf.d/99proxy && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7890";' >> /etc/apt/apt.conf.d/99proxy && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
    autoconf \
    automake \
    make \
    wget \
    libtool \
    pkg-config && \
    rm /etc/apt/apt.conf.d/99proxy

# ==========================================
# 2. 拉取源码 (配合原版 build.sh)
# ==========================================
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890

# 【关键】这里我必须加上 git checkout 2023-06-01
# 原因：原版 build.sh 依赖 'make'。
# 虽然你看到 GitHub 上可能有 Makefile，但 master 分支现在默认走 CMake/Bazel 流程，
# 只有切回 2023-06-01 才能保证根目录原本的 Makefile 逻辑 100% 跑通。
RUN git clone https://github.com/google/re2.git && \
    cd re2 && \
    git checkout 2023-06-01

RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# ==========================================
# 3. 注入资源
# ==========================================
# 保持原版逻辑：字典下载到 $OUT
RUN wget --no-check-certificate -qO $OUT/fuzzer.dict \
    https://raw.githubusercontent.com/google/fuzzing/master/dictionaries/regexp.dict

# 保持原版逻辑：文件复制到 $SRC
# build.sh 在 $SRC 下，所以它运行 'cd re2' 是正确的
COPY build.sh target.cc $SRC/
RUN chmod +x $SRC/build.sh

# 清理代理
ENV http_proxy=""
ENV https_proxy=""
