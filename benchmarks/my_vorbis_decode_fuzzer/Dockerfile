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
# 【核心修复】：强行清除环境变量代理，换源并直连阿里云，完美避开 502 报错
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --fix-missing \
    make \
    automake \
    autoconf \
    libtool \
    wget \
    pkg-config

# ==========================================
# 2. 开启全局代理 & 配置 Git (防断连)
# ==========================================
# apt 安装完毕后，注入代理，供后面的 wget 和 git 使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# ==========================================
# 3. 拉取源码 (保持原版逻辑)
# ==========================================
# Ogg (锁定特定的历史 Commit)
RUN git clone https://github.com/xiph/ogg.git && \
    git -C ogg checkout db5c7a49ce7ebda47b15b78471e78fb7f2483e22

# Vorbis (全量克隆)
RUN git clone https://github.com/xiph/vorbis.git

# 下载 Fuzzer 代码 (Wget 自动走上面设置的 ENV 代理)
RUN wget --no-check-certificate -qO $SRC/decode_fuzzer.cc \
    https://raw.githubusercontent.com/google/oss-fuzz/688aadaf44499ddada755562109e5ca5eb3c5662/projects/vorbis/decode_fuzzer.cc

# 恢复 Git 配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 4. 注入文件
# ==========================================
# 使用你本地提供的 build.sh
COPY build.sh $SRC/

# 使用你本地提供的 seeds
ADD seeds /opt/seeds

# ==========================================
# 5. 清理环境变量
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
