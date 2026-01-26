# Copyright 2020 Google LLC
ARG parent_image
FROM $parent_image

# ==========================================
# 1. 代理与依赖 (保持不变)
# ==========================================
ENV http_proxy=http://192.168.21.1:7890
ENV https_proxy=http://192.168.21.1:7890

RUN apt-get update && \
    apt-get install -y \
    wget git make \
    clang-10 llvm-10 llvm-10-dev \
    libc++-dev libc++abi-dev \
    pkg-config libtool automake autoconf \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 环境标准化 (保持不变)
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
# 3. 拉取 AFLFast 源码 (保持不变)
# ==========================================
RUN git clone https://github.com/mboehme/aflfast.git /afl && \
    cd /afl && \
    git checkout d1d54caf9850ca4afe2ac634a2a212aa6bb40032

# ==========================================
# 4. 手动编译 AFLFast (保持不变)
# ==========================================
RUN cd /afl && \
    CC=clang CXX=clang++ AFL_NO_X86=1 make && \
    cd llvm_mode && \
    clang-10 -O3 -Wall -g -Wno-pointer-sign \
      -DAFL_PATH=\"/afl\" -DBIN_PATH=\"/usr/bin\" -DVERSION=\"2.52b\" \
      afl-clang-fast.c -o afl-clang-fast && \
    clang++-10 -O3 -funroll-loops -fno-rtti -fPIC -shared \
      -I/usr/lib/llvm-10/include \
      afl-llvm-pass.so.cc -o afl-llvm-pass.so && \
    clang-10 -O3 -fPIC -fno-omit-frame-pointer -g -c \
      afl-llvm-rt.o.c -o afl-llvm-rt.o && \
    ln -sf afl-clang-fast afl-clang-fast++ && \
    cp afl-clang-fast /usr/bin/afl-clang-fast && \
    cp afl-clang-fast++ /usr/bin/afl-clang-fast++ && \
    cp afl-llvm-pass.so /afl/afl-llvm-pass.so && \
    cp afl-llvm-rt.o /afl/afl-llvm-rt.o && \
    cp /afl/afl-fuzz /usr/bin/fuzz && \
    chmod +x /usr/bin/afl-clang-fast /usr/bin/afl-clang-fast++ /usr/bin/fuzz

# ==========================================
# 5. 编译 Driver (修正此处)
# ==========================================
RUN cd /afl && \
    wget https://raw.githubusercontent.com/llvm/llvm-project/5feb80e748924606531ba28c97fe65145c65372e/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -O /afl/afl_driver.cpp && \
    \
    # 1. 编译 Driver 本体的 Runtime (afl-llvm-rt.o)
    #    这里生成的 .o 包含了 __afl_manual_init 等核心函数的定义
    clang-10 -Wno-pointer-sign -c -o /afl/afl-llvm-rt.o /afl/llvm_mode/afl-llvm-rt.o.c -I/afl && \
    \
    # 2. 编译 Driver 接口 (afl_driver.o)
    #    这里只生成 .o，不加静态链接参数
    clang++-10 -stdlib=libc++ -std=c++11 -O2 -c -o /afl/afl_driver.o /afl/afl_driver.cpp && \
    \
    # 3. 【关键修改】将 Driver 和 Runtime 同时打包进 libAFL.a
    #    这样链接器就能在同一个库里找到所有的符号定义了
    ar r /libAFL.a /afl/afl_driver.o /afl/afl-llvm-rt.o

# ==========================================
# 6. 环境变量
# ==========================================
ENV AFL_PATH=/afl
ENV CC=/usr/bin/afl-clang-fast
ENV CXX=/usr/bin/afl-clang-fast++
ENV FUZZER_LIB=/libAFL.a
ENV AFL_LLVM_MODE=1
ENV LIB_FUZZING_ENGINE=/libAFL.a

# 清除代理
ENV http_proxy=""
ENV https_proxy=""
