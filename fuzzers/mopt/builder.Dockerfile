# Copyright 2020 Google LLC
# ... (头部注释)

ARG parent_image
FROM $parent_image

# ==========================================
# 阶段 1: 编译插件 (Plugin)
# 目标: 强制使用 GNU libstdc++ 以兼容 Clang
# ==========================================

# 1. 安装 LLVM 10 并卸载 libc++
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7890";' > /etc/apt/apt.conf.d/proxy.conf && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7890";' >> /etc/apt/apt.conf.d/proxy.conf && \
    apt-get update && \
    apt-get install -y \
        git \
        make \
        build-essential \
        wget \
        ca-certificates \
        libtool-bin \
        automake \
        bison \
        flex \
        python3 \
        clang-10 \
        llvm-10 \
        llvm-10-dev && \
    apt-get remove -y libc++-dev libc++abi-dev && \
    apt-get autoremove -y && \
    rm /etc/apt/apt.conf.d/proxy.conf

# 2. 清除干扰
RUN rm -rf /usr/local/include/llvm && \
    rm -rf /usr/local/include/llvm-c && \
    rm -f /usr/local/bin/llvm* && \
    rm -f /usr/local/bin/clang* && \
    rm -f /usr/local/bin/opt

# 3. 设置 LLVM 10 默认
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-10 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-10 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-10 100 && \
    update-alternatives --install /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-10 100 && \
    update-alternatives --install /usr/bin/llvm-as llvm-as /usr/bin/llvm-as-10 100

# 4. 拉取源码
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone https://github.com/puppet-meteor/MOpt-AFL /afl && \
    cd /afl && \
    git checkout 45b9f38d2d8b699fd571cfde1bf974974339a21e && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# 5. 【关键修复】编译插件并复制二进制文件
# 我们把编译好的 afl-fuzz 和 afl-showmap 复制到 /afl 根目录
# 这样 fuzzer.py 脚本就能找到它们了
RUN cd /afl/MOpt && \
    AFL_NO_X86=1 make && \
    cd llvm_mode && \
    CXXFLAGS="-stdlib=libstdc++ -O3 -funroll-loops" LLVM_CONFIG=llvm-config-10 make && \
    cp /afl/MOpt/afl-fuzz /afl/afl-fuzz && \
    cp /afl/MOpt/afl-showmap /afl/afl-showmap

# ==========================================
# 阶段 2: 编译驱动 (Driver)
# 目标: 强制使用 LLVM libc++ 以兼容 Benchmark
# ==========================================

# 6. 装回 libc++
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7890";' > /etc/apt/apt.conf.d/proxy.conf && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7890";' >> /etc/apt/apt.conf.d/proxy.conf && \
    apt-get update && \
    apt-get install -y libc++-dev libc++abi-dev && \
    rm /etc/apt/apt.conf.d/proxy.conf

# 7. 编译驱动并打包 Runtime
RUN cd /afl/MOpt && \
    https_proxy=http://192.168.21.1:7890 wget https://raw.githubusercontent.com/llvm/llvm-project/5feb80e748924606531ba28c97fe65145c65372e/compiler-rt/lib/fuzzer/afl/afl_driver.cpp -O /afl/MOpt/afl_driver.cpp && \
    clang-10 -Wno-pointer-sign -c -o /afl/MOpt/afl-llvm-rt.o /afl/MOpt/llvm_mode/afl-llvm-rt.o.c -I/afl/MOpt && \
    clang++-10 -stdlib=libc++ -fPIC -O2 -c -o /afl/MOpt/afl_driver.o /afl/MOpt/afl_driver.cpp && \
    ar r /libAFL.a /afl/MOpt/afl_driver.o /afl/MOpt/afl-llvm-rt.o

# 8. 环境变量
ENV CC=/afl/MOpt/afl-clang-fast \
    CXX=/afl/MOpt/afl-clang-fast++ \
    AFL_LLVM_MODE=1 \
    FUZZER_LIB=/libAFL.a \
    LIB_FUZZING_ENGINE=/libAFL.a \
    AFL_PATH=/afl/MOpt
