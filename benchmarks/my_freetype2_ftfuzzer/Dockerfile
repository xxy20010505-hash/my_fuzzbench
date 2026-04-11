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
# 1. 基础依赖 (保持不变)
# ==========================================
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
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
RUN git clone --depth 1 https
