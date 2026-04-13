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

# 使用官方基础镜像
FROM gcr.io/oss-fuzz-base/base-builder@sha256:87ca1e9e19235e731fac8de8d1892ebe8d55caf18e7aa131346fc582a2034fdd

# ==========================================
# 1. 基础依赖 (绝对直连模式)
# ==========================================
# 【核心修复】：强行清除环境变量代理，换源并直连阿里云，完美避开 502 报错
# 安装构建依赖 (保留了 gnome-common 和 python-dev)
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
        make autoconf libtool pkg-config \
        zlib1g-dev zlib1g-dev:i386 liblzma-dev liblzma-dev:i386 \
        gnome-common python-dev

# ==========================================
# 2. 开启全局代理 & 安装 Automake
# ==========================================
# apt 安装完毕后，注入 172 代理，供后续 curl 和 git 翻墙使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

RUN curl -LO http://mirrors.kernel.org/ubuntu/pool/main/a/automake-1.16/automake_1.16.5-1.3_all.deb && \
    apt install -y ./automake_1.16.5-1.3_all.deb && \
    rm ./automake_1.16.5-1.3_all.deb

# ==========================================
# 3. 拉取源码 (修复路径与版本回退问题)
# ==========================================
# 配置 Git 代理与大文件传输优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# 【关键修复】
# 1. 明确指定克隆到 /src/libxml2
# 2. 移除了 --depth 1 和 --branch 限制。全量克隆能保证 FuzzBench 无论如何都能成功回退到旧版本的 commit。
RUN git clone https://gitlab.gnome.org/GNOME/libxml2.git /src/libxml2

# 清理 Git 代理配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 4. 配置工作目录与构建脚本
# ==========================================
# 强制设置工作目录，确保 build.sh 运行时就在这里
WORKDIR /src/libxml2

# 复制 FuzzBench 提供的 build.sh
COPY build.sh $SRC/

# 【调试】打印一下目录内容，如果构建失败，看日志里有没有 autogen.sh
RUN echo "Checking directory content:" && ls -la /src/libxml2

# ==========================================
# 5. 清理环境变量
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
