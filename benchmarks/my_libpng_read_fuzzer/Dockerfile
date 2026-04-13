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
# 【核心修复】：在这里绝对不写 ENV proxy，让 apt-get 以纯粹的本地网络直连阿里云
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --fix-missing \
    make autoconf automake libtool zlib1g-dev pkg-config \
    zip

# ==========================================
# 2. 开启全局代理 & 准备源码
# ==========================================
# apt 安装完毕后，我们再注入代理，供后面的组件使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

# 配置 Git 代理与优化
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# (A) 克隆 Zlib (带版本号分支，使用 depth 1 是安全的)
RUN git clone --depth 1 --branch v1.2.13 https://github.com/madler/zlib.git $SRC/zlib

# (B) 克隆 Libpng 
# 保留完整历史，防止 FuzzBench 回退代码时失败
RUN git clone https://github.com/glennrp/libpng.git $SRC/libpng

# 恢复 Git 配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 3. 注入构建脚本
# ==========================================
WORKDIR $SRC/libpng

# 复制 build.sh
COPY build.sh $SRC/build.sh
RUN chmod +x $SRC/build.sh

# ==========================================
# 4. 字典与种子
# ==========================================
# 刚才在 Step 2 注入的 ENV 代理在这里会起作用，确保能连上 raw.githubusercontent.com
RUN wget --no-check-certificate -qO $SRC/libpng_read_fuzzer.dict \
    https://raw.githubusercontent.com/google/fuzzing/master/dictionaries/png.dict

ADD seeds /opt/seeds
COPY * $SRC/

# ==========================================
# 5. 清理代理，保持镜像纯净
# ==========================================
ENV http_proxy=""
ENV https_proxy=""
