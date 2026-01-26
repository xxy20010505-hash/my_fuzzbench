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

FROM gcr.io/fuzzbench/base-image

# 必须再次设置代理，因为 Runner 构建是独立的阶段
ENV http_proxy=http://192.168.21.1:7890
ENV https_proxy=http://192.168.21.1:7890

# 安装运行时缺失的库：libc++1 和 libc++abi1
RUN apt-get update && apt-get install -y \
    libc++1 \
    libc++abi1 \
    && rm -rf /var/lib/apt/lists/*

# 清除代理
ENV http_proxy=""
ENV https_proxy=""
