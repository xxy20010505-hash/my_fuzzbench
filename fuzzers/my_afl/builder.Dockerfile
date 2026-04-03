ARG parent_image
FROM $parent_image

# ==========================================
# 1. 安装构建依赖
# ==========================================
RUN apt-get update && \
    apt-get install -y libhiredis-dev make git ca-certificates wget \
    clang-12 llvm-12 llvm-12-dev \
    libc++-12-dev libc++abi-12-dev \
    zlib1g-dev \
    pkg-config libtool automake autoconf

# ==========================================
# 2. 环境标准化 (Clang 软链接)
# ==========================================
RUN rm -rf /usr/local/include/llvm && \
    rm -f /usr/local/bin/llvm-config && \
    rm -f /usr/local/bin/clang* && \
    ln -sf /usr/bin/clang-12 /usr/bin/clang && \
    ln -sf /usr/bin/clang++-12 /usr/bin/clang++ && \
    ln -sf /usr/bin/llvm-config-12 /usr/bin/llvm-config && \
    ln -sf /usr/bin/llvm-ar-12 /usr/bin/llvm-ar && \
    ln -sf /usr/bin/llvm-as-12 /usr/bin/llvm-as && \
    ln -sf /usr/bin/llvm-link-12 /usr/bin/llvm-link

# ==========================================
# 3. 拉取源码 (改用绝对路径，不切换 WORKDIR)
# ==========================================
# 【关键修改】直接 clone 到 /afl，而不是先 WORKDIR 再 clone
RUN git config --global http.proxy http://172.17.0.1:7897 && \
    git config --global https.proxy http://172.17.0.1:7897 && \
    git clone https://github.com/xxy20010505-hash/afl-MlpAco.git /afl && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# ==========================================
# 4. 部署 ONNX
# ==========================================
# 【关键修改】使用 cd 命令，只在这一行生效
RUN cd /afl/onnxruntime && \
    (cp -r lib/* /usr/lib/ 2>/dev/null || : ) && \
    (cp *.so* /usr/lib/ 2>/dev/null || : ) && \
    (cp -r include/* /usr/include/ 2>/dev/null || : ) && \
    ldconfig

# ==========================================
# 5. 编译 AFL 核心
# ==========================================
# 【关键修改】cd /afl 进去编译
RUN cd /afl && \
    make clean && \
    CFLAGS= CXXFLAGS= AFL_NO_X86=1 make CC=clang CXX=clang++

# ==========================================
# 6. 编译 LLVM Mode
# ==========================================
# 【关键修改】全程使用绝对路径 + cd，不使用 WORKDIR
RUN cd /afl/llvm_mode && \
    clang-12 -O3 -Wall -g -Wno-pointer-sign \
      -DAFL_PATH=\"/afl\" -DBIN_PATH=\"/usr/bin\" -DVERSION=\"2.57b\" \
      afl-clang-fast.c -o afl-clang-fast && \
    clang++-12 -O3 -funroll-loops -fno-rtti -fPIC -shared \
      -I/usr/lib/llvm-12/include \
      afl-llvm-pass.so.cc -o afl-llvm-pass.so && \
    clang-12 -O3 -fPIC -fno-omit-frame-pointer -g -c \
      afl-llvm-rt.o.c -o afl-llvm-rt.o && \
    ln -sf afl-clang-fast afl-clang-fast++

# ==========================================
# 7. 制作 libAFL.a
# ==========================================
# 【关键修改】目标路径明确，不依赖当前目录
COPY afl_driver.cpp /afl/afl_driver.cpp
RUN clang++-12 -stdlib=libc++ -std=c++11 -O2 -c /afl/afl_driver.cpp -o afl_driver.o && \
    ar r /libAFL.a afl_driver.o

# ==========================================
# 8. 归位与安装
# ==========================================
RUN cp /afl/llvm_mode/afl-llvm-pass.so /afl/ && \
    cp /afl/llvm_mode/afl-llvm-rt.o /afl/ && \
    cp /afl/afl-fuzz /usr/bin/fuzz && \
    cp /afl/llvm_mode/afl-clang-fast /usr/bin/afl-clang-fast && \
    cp /afl/llvm_mode/afl-clang-fast++ /usr/bin/afl-clang-fast++

# ==========================================
# 9. 环境变量
# ==========================================
ENV AFL_PATH=/afl
ENV AFL_CC=clang
ENV AFL_CXX=clang++
ENV CC=/usr/bin/afl-clang-fast
ENV CXX=/usr/bin/afl-clang-fast++
ENV FUZZER_LIB=/libAFL.a
