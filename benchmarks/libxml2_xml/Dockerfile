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
# 1. 全局代理设置
# ==========================================
# 定义 ENV 环境变量，这样 apt-get 和 curl 会自动通过代理下载
ENV http_proxy=http://192.168.21.1:7890
ENV https_proxy=http://192.168.21.1:7890

# ==========================================
# 2. 安装系统依赖
# ==========================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        make autoconf libtool pkg-config \
        zlib1g-dev zlib1g-dev:i386 liblzma-dev liblzma-dev:i386

# ==========================================
# 3. 手动下载 Automake
# ==========================================
# Curl 会自动读取上面的 http_proxy 环境变量
# Build requires automake 1.16.3
RUN curl -LO http://mirrors.kernel.org/ubuntu/pool/main/a/automake-1.16/automake_1.16.5-1.3_all.deb && \
    apt install ./automake_1.16.5-1.3_all.deb

# ==========================================
# 4. 拉取源码 (Git 代理配置)
# ==========================================
# Git 有时对 ENV 响应不敏感，显式配置 git config 最稳妥
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone https://gitlab.gnome.org/GNOME/libxml2.git && \
    # 拉取完成后清理 git 配置
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

WORKDIR libxml2
COPY build.sh $SRC/

# ==========================================
# 5. 清理环境变量
# ==========================================
# 构建完成后清空，避免带入 Runner 造成干扰
ENV http_proxy=""
ENV https_proxy=""
