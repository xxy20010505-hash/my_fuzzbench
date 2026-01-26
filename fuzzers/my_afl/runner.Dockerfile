FROM gcr.io/fuzzbench/base-image

# ==========================================
# 1. 安装系统运行库 (含关键修复: 升级 libstdc++)
# ==========================================
RUN echo 'Acquire::http::Proxy "http://192.168.21.1:7890";' > /etc/apt/apt.conf.d/proxy.conf && \
    echo 'Acquire::https::Proxy "http://192.168.21.1:7890";' >> /etc/apt/apt.conf.d/proxy.conf && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    # [关键修复步骤 START] ---------------------------------
    # 1. 安装 add-apt-repository 工具
    apt-get install -y --no-install-recommends software-properties-common && \
    # 2. 添加 Toolchain 源 (为了获取支持 GLIBCXX_3.4.2x 的新版标准库)
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    # 3. 安装 libstdc++6 (这是 ONNX Runtime 必须的)
    #    同时保留 libc++1 以兼容 Clang 环境
    apt-get install -y --no-install-recommends \
    libstdc++6 \
    git ca-certificates python3-pip redis-server libhiredis0.14 \
    libc++1 libc++abi1 \
    libglib2.0-0 liblzma5 zlib1g \
    wget tar dos2unix && \
    # [关键修复步骤 END] -----------------------------------
    rm /etc/apt/apt.conf.d/proxy.conf && \
    rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 安装 Python 依赖
# ==========================================
RUN export http_proxy=http://192.168.21.1:7890 && \
    export https_proxy=http://192.168.21.1:7890 && \
    pip3 install --no-cache-dir torch==2.4.0+cpu --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install --no-cache-dir "protobuf==6.33.4" "onnx==1.20.1" "onnxscript==0.5.6" "onnxruntime==1.23.2" "numpy==1.23.4" -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    rm -rf /usr/local/lib/python3.10/site-packages/onnx/backend/test/data

# ==========================================
# 3. 拉取代码
# ==========================================
WORKDIR /afl
RUN git config --global http.proxy http://192.168.21.1:7890 && \
    git config --global https.proxy http://192.168.21.1:7890 && \
    git clone --depth 1 https://github.com/xxy20010505-hash/afl-MlpAco.git . && \
    git config --global --unset http.proxy && \
    git config --global --unset https.proxy

# ==========================================
# 4. 部署 ONNX Runtime 库
# ==========================================
RUN if [ ! -d "/afl/onnxruntime/lib" ]; then echo "ERROR: /afl/onnxruntime/lib not found! Check your git repo."; exit 1; fi && \
    mkdir -p /opt/onnxruntime && \
    cp -r /afl/onnxruntime/lib /opt/onnxruntime/lib && \
    chmod -R 755 /opt/onnxruntime/lib

# ==========================================
# 5. 扫尾工作
# ==========================================
RUN chmod +x /afl/*.py

ENV LD_LIBRARY_PATH="/opt/onnxruntime/lib:${LD_LIBRARY_PATH}"
ENV PYTHONPATH="/afl:${PYTHONPATH}"

WORKDIR /
