FROM gcr.io/fuzzbench/dispatcher-image:latest
RUN pip3 install "setuptools==59.6.0" -i https://pypi.tuna.tsinghua.edu.cn/simple
