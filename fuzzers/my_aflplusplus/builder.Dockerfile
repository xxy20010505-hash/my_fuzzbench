ARG parent_image
FROM $parent_image

# ==========================================
# 1. 安装依赖 (关键修复：加入了 clang 和 llvm)
# ==========================================
# AFL++ 强烈依赖 Clang 和 LLVM，必须显式安装
RUN apt-get update && \
    apt-get install -y \
        build-essential \
        python3-dev \
        python3-setuptools \
        automake \
        cmake \
        git \
        flex \
        bison \
        libglib2.0-dev \
        libpixman-1-dev \
        cargo \
        libgtk-3-dev \
        ninja-build \
        # 【重点】安装 Clang 和 LLVM
        clang \
        llvm \
        llvm-dev \
        lld \
        # 保留 gcc 兼容性
        gcc \
        g++ \
    && rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 下载 AFL++ (切换到 stable 分支)
# ==========================================
# 建议使用 stable 分支，dev 分支变动太快容易挂
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone -b stable https://github.com/AFLplusplus/AFLplusplus /afl && \
    cd /afl && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# ==========================================
# 3. 编译 AFL++ (使用 source-only 模式)
# ==========================================
RUN cd /afl && \
    # 清理环境变量，防止干扰
    unset CFLAGS CXXFLAGS && \
    # 指定编译器为 clang
    export CC=clang && \
    export CXX=clang++ && \
    export AFL_NO_X86=1 && \
    export AFL_NO_PYTHON=1 && \
    # 【重点】使用 source-only 目标，跳过 QEMU/Unicorn 编译，大大提高成功率
    make source-only && \
    # 编译 Driver
    make -C utils/aflpp_driver && \
    # 复制文件
    cp utils/aflpp_driver/libAFLDriver.a /libAFLDriver.a && \
    cp afl-fuzz /out/ && \
    cp afl-showmap /out/ && \
    cp afl-tmin /out/ && \
    cp afl-gotcpu /out/ && \
    cp afl-analyze /out/

# ==========================================
# 4. 设置环境变量
# ==========================================
# 告诉 Fuzzer.py 和后续的 Benchmark 使用 AFL++ 的编译器
ENV CC=/afl/afl-clang-fast
ENV CXX=/afl/afl-clang-fast++
ENV FUZZER_LIB=/libAFLDriver.a
ENV AFL_MAP_SIZE=262144
