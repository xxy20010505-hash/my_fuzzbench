# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG parent_image
FROM $parent_image

# 【新增】：定义代理参数，你可以修改这里的默认值为你常用的代理
ARG PROXY_URL="http://192.168.21.1:7890"

# 1. 安装工具 (为了保险，给 apt 也加上代理配置，虽然 apt 通常用国内源)
RUN apt-get update && \
    apt-get install -y wget ca-certificates make clang llvm && \
    rm -rf /var/lib/apt/lists/*

# 2. 下载 AFL (git clone 也加上代理)
RUN git config --global http.proxy $PROXY_URL && \
    git clone --depth 1 https://github.com/Fuzzers-Archive/afl-2.52b.git /afl && \
    git config --global --unset http.proxy && \
    cd /afl && \
    AFL_NO_X86=1 make

# 3. 下载 afl_driver.cpp (给 wget 加上代理)
RUN https_proxy=$PROXY_URL wget https://raw.githubusercontent.com/llvm/llvm-project/5feb80e748924606531ba28c97fe65145c65372e/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -O /afl/afl_driver.cpp && \
    clang -Wno-pointer-sign -c /afl/llvm_mode/afl-llvm-rt.o.c -I/afl && \
    clang++ -stdlib=libc++ -std=c++11 -O2 -c /afl/afl_driver.cpp && \
    ar r /libAFL.a *.o
