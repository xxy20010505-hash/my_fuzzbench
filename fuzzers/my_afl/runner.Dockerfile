FROM gcr.io/fuzzbench/base-image

# ==========================================
# 0. 设置全局构建代理与白名单（双轨分流核心）
# ==========================================
# Git, PyTorch 自动走代理；清华源、本地网络直连
ENV http_proxy=http://172.17.0.1:7897 \
    https_proxy=http://172.17.0.1:7897 \
    no_proxy="localhost,127.0.0.1,.tsinghua.edu.cn"

# ==========================================
# 1. 安装系统运行库 (含关键修复: 升级 libstdc++)
# ==========================================
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    apt-get update && \
    # 1. 安装 add-apt-repository 工具
    apt-get install -y --no-install-recommends software-properties-common && \
    # 2. 添加 Toolchain 源 (因为不在 no_proxy 中，此步骤会自动走代理，防卡死)
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
    rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 安装 Python 依赖
# ==========================================
RUN pip3 install --no-cache-dir torch==2.4.0+cpu --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install --no-cache-dir "protobuf==6.33.4" "onnx==1.20.1" "onnxscript==0.5.6" "onnxruntime==1.23.2" "numpy==1.23.4" -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    rm -rf /usr/local/lib/python3.10/site-packages/onnx/backend/test/data

# ==========================================
# 3. 拉取代码
# ==========================================
WORKDIR /afl
# 依赖顶部 ENV 变量，自动走代理拉取 GitHub，不再需要繁琐的 git config
RUN git clone --depth 1 https://github.com/xxy20010505-hash/afl-MlpAco.git .

# ==========================================
# 4. 部署 ONNX Runtime 库
# ==========================================
RUN if [ ! -d "/afl/onnxruntime/lib" ]; then echo "ERROR: /afl/onnxruntime/lib not found! Check your git repo."; exit 1; fi && \
    mkdir -p /opt/onnxruntime && \
    cp -r /afl/onnxruntime/lib /opt/onnxruntime/lib && \
    chmod -R 755 /opt/onnxruntime/lib

# ==========================================
# 5. 扫尾工作与环境变量重置
# ==========================================
RUN chmod +x /afl/*.py

# 【关键】卸载构建时的网络代理，防止容器运行时 Redis 通信走代理导致连接被拒
ENV http_proxy="" \
    https_proxy="" \
    no_proxy=""

ENV LD_LIBRARY_PATH="/opt/onnxruntime/lib:${LD_LIBRARY_PATH}"
ENV PYTHONPATH="/afl:${PYTHONPATH}"

WORKDIR /
