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
# 1. 网络配置与依赖 (绝对直连模式)
# ==========================================
# 【核心修复】：加上 unset 结界强行清空代理，让 apt-get 纯粹直连阿里云，完美避开 502
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
# apt 安装完毕后，再将代理注入环境，供后面的 Git 和 wget 翻墙使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 配置 Git 代理与大文件传输优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# 【关键保留】：全量克隆并回退到旧版 commit，保证原始 build.sh 的 make 命令 100% 跑通
RUN git clone https://github.com/google/re2.git && \
    cd re2 && \
    git checkout 2023-06-01

# 恢复 Git 默认配置
