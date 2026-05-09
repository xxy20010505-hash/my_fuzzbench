FROM gcr.io/fuzzbench/base-image

# ==========================================
# 1. 安装系统运行库 (绝对直连 + PPA 独立代理)
# ==========================================
# 【专家修正】：移除头部的全局 ENV 代理。Ubuntu 基础源换为阿里云直连。
RUN unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY && \
    sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    # 【关键打击】：Launchpad PPA 的 GPG 密钥服务器经常被墙，仅在这一行命令单独注入代理！
    http_proxy=http://172.17.0.1:7897 https_proxy=http://172.17.0.1:7897 \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
    apt-get update && \
    # 基础依赖安装，享受国内镜像直连的满速
    apt-get install -y --no-install-recommends \
    libstdc++6 \
    git ca-certificates python3-pip redis-server libhiredis0.14 \
    libc++1 libc++abi1 \
    libglib2.0-0 liblzma5 zlib1g \
    wget tar dos2unix && \
    rm -rf /var/lib/apt/lists/*

# ==========================================
# 2. 安装 Python 依赖 (精细化路由分流)
# ==========================================
# 【专家修正】：不依赖环境变量，直接使用 pip 原生的 --proxy 参数抓取 PyTorch，
# 随后的普通包使用 -i 走清华源直连。
RUN pip3 install --proxy http://172.17.0.1:7897 --no-cache-dir torch==2.4.0+cpu --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install --no-cache-dir "protobuf==6.33.4" "onnx==1.20.1" "onnxscript==0.5.6" "onnxruntime==1.23.2" "numpy==1.23.4" -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    rm -rf /usr/local/lib/python3.10/site-packages/onnx/backend/test/data

# ==========================================
# 3. 拉取代码 (内联代理)
# ==========================================
WORKDIR /afl
# 【专家修正】：阅后即焚式代理，不修改任何 Git 全局配置
RUN https_proxy=http://172.17.0.1:7897 \
    git clone --depth 1 https://github.com/xxy20010505-hash/afl-MlpAco.git .

# ==========================================
# 4. 部署 ONNX Runtime 库
# ==========================================
RUN if [ ! -d "/afl/onnxruntime/lib" ]; then echo "ERROR: /afl/onnxruntime/lib not found! Check your git repo."; exit 1; fi && \
    mkdir -p /opt/onnxruntime && \
    cp -r /afl/onnxruntime/lib /opt/onnxruntime/lib && \
    chmod -R 755 /opt/onnxruntime/lib

# ==========================================
# 5. 扫尾工作与环境变量
# ==========================================
RUN chmod +x /afl/*.py

# 【最终优势】：由于我们全程没有使用任何 ENV http_proxy 命令，
# Runner 容器天生就是“物理隔离”状态的。你甚至都不需要在这里 unset 任何东西！
# 你的 Redis 和 Python Actor 之间的本地通信将畅通无阻。
ENV LD_LIBRARY_PATH="/opt/onnxruntime/lib:${LD_LIBRARY_PATH}"
ENV PYTHONPATH="/afl:${PYTHONPATH}"

WORKDIR /
