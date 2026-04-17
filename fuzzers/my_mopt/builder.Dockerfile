# Copyright 2020 Google LLC
ARG parent_image
FROM $parent_image

# ==========================================
# 1. 基础依赖 (绝对直连模式)
# ==========================================
# 【核心修复】：强行清除环境变量代理，换源并直连阿里云，完美避开 502 报错
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --fix-missing \
    wget git make \
    clang-10 llvm-10 llvm-10-dev \
    libc++-dev libc++abi-dev \
    pkg-config libtool automake autoconf \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 注入全局代理 & 配置 Git
# ==========================================
# apt-get 跑完后，再注入代理，供后面的 Git 和 wget 翻墙使用
ENV http_proxy=http://172.17.0.1:7897
ENV https_proxy=http://172.17.0.1:7897

RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git config --global http.version HTTP/1.1 && \
    git config --global http.postBuffer 524288000

# ==========================================
# 3. 环境标准化
# ==========================================
RUN rm -rf /usr/local/include/llvm && \
    rm -f /usr/local/bin/llvm-config && \
    rm -f /usr/local/bin/clang* && \
    ln -sf /usr/bin/clang-10 /usr/bin/clang && \
    ln -sf /usr/bin/clang++-10 /usr/bin/clang++ && \
    ln -sf /usr/bin/llvm-config-10 /usr/bin/llvm-config && \
    ln -sf /usr/bin/llvm-ar-10 /usr/bin/llvm-ar && \
    ln -sf /usr/bin/llvm-as-10 /usr/bin/llvm-as && \
    ln -sf /usr/bin/llvm-link-10 /usr/bin/llvm-link

# ==========================================
# 4. 拉取源码
# ==========================================
RUN git clone https://github.com/puppet-meteor/MOpt-AFL /afl && \
    cd /afl && \
    git checkout 45b9f38d2d8b699fd571cfde1bf974974339a21e

# 恢复 Git 默认配置
RUN git config --global --unset http.proxy && \
    git config --global --unset https.proxy && \
    git config --global --unset http.version && \
    git config --global --unset http.postBuffer

# ==========================================
# 5. 编译 MOpt (保持原版逻辑)
# ==========================================
RUN cd /afl/MOpt && \
    CC=clang CXX=clang++ AFL_NO_X86=1 make && \
    cd llvm_mode && \
    # 编译 Wrapper
    clang-10 -O3 -Wall -g -Wno-pointer-sign \
      -DAFL_PATH=\"/afl/MOpt\" -DBIN_PATH=\"/usr/bin\" -DVERSION=\"2.52b\" \
      afl-clang-fast.c -o afl-clang-fast && \
    # 编译 Pass
    clang++-10 -O3 -funroll-loops -fno-rtti -fPIC -shared \
      -I/usr/lib/llvm-10/include \
      afl-llvm-pass.so.cc -o afl-llvm-pass.so && \
    # 编译 Runtime
    clang-10 -O3 -fPIC -fno-omit-frame-pointer -g -c \
      afl-llvm-rt.o.c -o afl-llvm-rt.o && \
    # 链接
    ln -sf afl-clang-fast afl-clang-fast++ && \
    # -------------------------------------------------------------------
    # (G) 归位与兼容性修复
    # -------------------------------------------------------------------
    # 1. 编译器放到系统目录
    cp afl-clang-fast /usr/bin/afl-clang-fast && \
    cp afl-clang-fast++ /usr/bin/afl-clang-fast++ && \
    # 2. 插件和运行时放回 AFL_PATH
    cp afl-llvm-pass.so /afl/MOpt/afl-llvm-pass.so && \
    cp afl-llvm-rt.o /afl/MOpt/afl-llvm-rt.o && \
    # 3. 创建软链接，欺骗 fuzzer.py
    ln -sf /afl/MOpt/afl-fuzz /afl/afl-fuzz && \
    ln -sf /afl/MOpt/afl-showmap /afl/afl-showmap && \
    ln -sf /afl/MOpt/afl-tmin /afl/afl-tmin && \
    ln -sf /afl/MOpt/afl-gotcpu /afl/afl-gotcpu && \
    # 4. FuzzBench 标准位置
    cp /afl/MOpt/afl-fuzz /usr/bin/fuzz

# ==========================================
# 6. 编译 Driver (保持原版逻辑)
# ==========================================
RUN cd /afl/MOpt && \
    wget https://raw.githubusercontent.com/llvm/llvm-project/5feb80e748924606531ba28c97fe65145c65372e/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -O /afl/MOpt/afl_driver.cpp && \
    clang-10 -Wno-pointer-sign -c -o /afl/MOpt/afl-llvm-rt.o /afl/MOpt/llvm_mode/afl-llvm-rt.o.c -I/afl/MOpt && \
    clang++-10 -stdlib=libc++ -std=c++11 -O2 -c -o /afl/MOpt/afl_driver.o /afl/MOpt/afl_driver.cpp && \
    ar r /libAFL.a /afl/MOpt/afl_driver.o /afl/MOpt/afl-llvm-rt.o

# ==========================================
# 7. 环境变量
# ==========================================
ENV AFL_PATH=/afl/MOpt
ENV CC=/usr/bin/afl-clang-fast
ENV CXX=/usr/bin/afl-clang-fast++
ENV AFL_LLVM_MODE=1
ENV FUZZER_LIB=/libAFL.a
ENV LIB_FUZZING_ENGINE=/libAFL.a

# 清除代理
ENV http_proxy=""
ENV https_proxy=""
