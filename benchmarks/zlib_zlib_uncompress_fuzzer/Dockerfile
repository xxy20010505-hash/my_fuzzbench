# Copyright 2016 Google Inc.
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

# 1. 安装依赖 & 极速清理 (核心优化点)
# - sed: 换源
# - apt-get update: 更新列表
# - install --no-install-recommends: 不安装推荐的非必须包 (极大节省空间)
# - apt-get clean & rm -rf: 【关键】安装完立刻删掉缓存，防止写入镜像层
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends make autoconf automake libtool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. 拉取源码 (使用本地代理)
# 注意：这里直接 clone 到 zlib 目录，这会自动创建该目录
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone --depth 1 -b develop https://github.com/madler/zlib.git zlib && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# 3. 设置工作目录 (进入刚才 clone 的文件夹)
WORKDIR zlib

# 4. 复制构建脚本到源码根目录 ($SRC 通常是 /src)
COPY build.sh zlib_uncompress_fuzzer.cc $SRC/
