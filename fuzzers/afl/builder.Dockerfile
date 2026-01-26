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

# Download and compile AFL v2.57b.
# Set AFL_NO_X86 to skip flaky tests.
# 【修改点1】Git Clone 代理
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone \
        --depth 1 \
        --branch v2.57b \
        https://github.com/google/AFL.git /afl && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    cd /afl && \
    CFLAGS= CXXFLAGS= AFL_NO_X86=1 make

# Use afl_driver.cpp from LLVM as our fuzzing library.
# 【修改点2】Wget 代理
# 我们在 wget 前面加上 https_proxy=... 临时环境变量
RUN apt-get update && \
    apt-get install wget -y && \
    https_proxy=http://192.168.21.1:7890 wget https://raw.githubusercontent.com/llvm/llvm-project/5feb80e748924606531ba28c97fe65145c65372e/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -O /afl/afl_driver.cpp && \
    clang -Wno-pointer-sign -c /afl/llvm_mode/afl-llvm-rt.o.c -I/afl && \
    clang++ -stdlib=libc++ -std=c++11 -O2 -c /afl/afl_driver.cpp && \
    ar r /libAFL.a *.o
