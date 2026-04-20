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

FROM ubuntu:focal

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3.10.8

# =================================================================
# 1. 基础系统依赖 (完全直连阿里云，彻底消灭 502)
# =================================================================
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --fix-missing \
    curl \
    xz-utils \
    build-essential \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    liblzma-dev

# =================================================================
# 2. 注入代理，加速下载并编译 Python 和 pip 包
# =================================================================
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 这一步的 curl 会自动使用上面的代理，秒下 Python 源码
RUN cd /tmp/ && \
    curl -O https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz && \
    tar -xvf Python-$PYTHON_VERSION.tar.xz > /dev/null && \
    cd Python-$PYTHON_VERSION && \
    ./configure \
        --enable-loadable-sqlite-extensions \
        --enable-optimizations \
        > /dev/null && \
    make -j install > /dev/null && \
    rm -r /tmp/Python-$PYTHON_VERSION.tar.xz /tmp/Python-$PYTHON_VERSION && \
    ln -s /usr/local/bin/python3 /usr/local/bin/python && \
    ln -s /usr/local/bin/pip3 /usr/local/bin/pip

# Install common python dependencies (走代理下载更快)
COPY ./requirements.txt /tmp
RUN pip install -r /tmp/requirements.txt

# =================================================================
# 3. 安装额外的 apt 依赖 (必须再次清空代理)
# =================================================================
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    apt-get update && \
    apt-get install -y --fix-missing \
    apt-transport-https \
    ca-certificates \
    rsync \
    gnupg

# =================================================================
# 4. 清理环境变量
# =================================================================
ENV http_proxy=""
ENV https_proxy=""

# (如果你以后需要用到 google-cloud-cli，取消下面的注释即可。目前在本地跑实验不需要它)
#RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk main" \
#    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
#    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
#    | apt-key add - && \
#    apt-get update && \
#    apt-get install -y google-cloud-cli
