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
ENV http_proxy=http://192.168.21.1:7890
ENV https_proxy=http://192.168.21.1:7890

# 换源 + 安装依赖
# 【新增】zip (因为 build.sh 需要用到)
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7890";' > /etc/apt/apt.conf.d/99proxy && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7890";' >> /etc/apt/apt.conf.d/99proxy && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
    make autoconf automake libtool zlib1g-dev pkg-config \
    zip && \
    rm /etc/apt/apt.conf.d/99proxy

# ==========================================
# 2. 准备源码
# ==========================================
# Zlib (网络下载)
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# (A) 克隆 Zlib
RUN git clone --depth 1 --branch v1.2.13 https://github.com/madler/zlib.git $SRC/zlib

# (B) 克隆 Libpng (恢复网络下载)
# 使用 --depth 1 只拉取最新版，速度快且不易失败
RUN git clone --depth 1 https://github.com/glennrp/libpng.git $SRC/libpng

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
RUN wget --no-check-certificate -qO $SRC/libpng_read_fuzzer.dict \
    https://raw.githubusercontent.com/google/fuzzing/master/dictionaries/png.dict

ADD seeds /opt/seeds
COPY * $SRC/

# ==========================================
# 6. 清理
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
