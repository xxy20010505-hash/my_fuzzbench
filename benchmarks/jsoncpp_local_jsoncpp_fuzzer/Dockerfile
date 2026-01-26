# Copyright 2019 Google Inc.
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

# 【修改点1】APT 代理
# 使用行内环境变量方式，确保 apt 能连上源（特别是如果你的 base image 用的是国外源）
RUN http_proxy=http://192.168.21.1:7890 https_proxy=http://192.168.21.1:7890 \
    apt-get update && \
    http_proxy=http://192.168.21.1:7890 https_proxy=http://192.168.21.1:7890 \
    apt-get install -y build-essential make curl wget

# Install latest cmake.
# 【修改点2】Wget 代理
# GitHub Releases 下载非常慢，必须加代理。
# 这里在命令前加上 https_proxy 变量即可。
RUN https_proxy=http://192.168.21.1:7890 \
    wget https://github.com/Kitware/CMake/releases/download/v3.14.5/cmake-3.14.5-Linux-x86_64.sh && \
    chmod +x cmake-3.14.5-Linux-x86_64.sh && \
    ./cmake-3.14.5-Linux-x86_64.sh --skip-license --prefix="/usr/local"

# 【修改点3】Git Clone 代理
# 采用你验证过的最稳妥的 git config 方式
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone https://github.com/open-source-parsers/jsoncpp && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

WORKDIR jsoncpp

# 1. 安装 unzip (如果是 base-builder 可能自带，但保险起见装一下)
RUN apt-get update && apt-get install -y unzip wget

COPY seeds.zip /tmp/seeds.zip

RUN mkdir -p /out/seeds && \
    unzip /tmp/seeds.zip -d /out/seeds && \
    rm /tmp/seeds.zip && \
    chmod -R 777 /out/seeds

COPY build.sh $SRC/
