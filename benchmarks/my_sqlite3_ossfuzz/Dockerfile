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

FROM gcr.io/oss-fuzz-base/base-builder@sha256:87ca1e9e19235e731fac8de8d1892ebe8d55caf18e7aa131346fc582a2034fdd

# ==========================================
# 1. 代理与依赖安装
# ==========================================
ENV http_proxy=http://172.17.0.1:7890
ENV https_proxy=http://172.17.0.1:7890

# 关键修改：
# 1. 加入 'zip'：后续生成种子库需要用到 zip 命令，基础镜像可能不带。
# 2. 加入 'tcl'：SQLite 构建的核心依赖。
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    make autoconf automake libtool curl \
    tcl zlib1g-dev \
    zip

# ==========================================
# 2. 下载源码
# ==========================================
# 使用绝对路径 /src/sqlite3，防止路径混淆
RUN mkdir -p /src/sqlite3 && \
    cd /src/sqlite3 && \
    # Curl 会自动使用上面的 ENV 代理
    # 加入 -L 以支持重定向，-v 以便调试链接情况
    curl -L 'https://sqlite.org/src/tarball/sqlite.tar.gz?r=c78cbf2e86850cc6' -o sqlite3.tar.gz && \
    tar xzf sqlite3.tar.gz --strip-components 1

# ==========================================
# 3. 生成种子库 (本地提取)
# ==========================================
# SQLite 使用源码里的 .test 文件作为 Fuzzing 种子
# 这一步依赖刚才安装的 'zip' 工具
RUN find /src/sqlite3 -name "*.test" | xargs zip $SRC/ossfuzz_seed_corpus.zip

# ==========================================
# 4. 配置构建环境
# ==========================================
WORKDIR /src/sqlite3
COPY build.sh *.dict $SRC/

# ==========================================
# 5. 清理环境变量
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
