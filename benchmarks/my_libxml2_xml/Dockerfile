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
# 1. 代理与基础依赖
# ==========================================
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 安装构建依赖
# 【重点】加入了 gnome-common (autogen.sh 依赖它)
# 加入了 python-dev (防止 configure 报错)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        make autoconf libtool pkg-config \
        zlib1g-dev zlib1g-dev:i386 liblzma-dev liblzma-dev:i386 \
        gnome-common python-dev

# ==========================================
# 2. 安装 Automake (保持不变)
# ==========================================
RUN curl -LO http://mirrors.kernel.org/ubuntu/pool/main/a/automake-1.16/automake_1.16.5-1.3_all.deb && \
    apt install ./automake_1.16.5-1.3_all.deb

# ==========================================
# 3. 拉取源码 (修复路径问题)
# ==========================================
# 【关键修复】
# 1. 明确指定克隆到 /src/libxml2
# 2. 切换到 tag v2.9.14 (保证 autogen.sh 肯定存在，master 分支可能已经换成 cmake 了)
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git clone --depth 1 --branch v2.9.14 https://gitlab.gnome.org/GNOME/libxml2.git /src/libxml2 && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

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
