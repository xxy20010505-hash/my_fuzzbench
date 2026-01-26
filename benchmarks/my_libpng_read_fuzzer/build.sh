#!/bin/bash -ex
# build.sh - Simplified Make

echo "=== [DEBUG] Starting build.sh ==="

# 1. 编译 Zlib
echo "=== [DEBUG] Building zlib ==="
cd "$SRC/zlib"
./configure --static
make -j$(nproc)

# 2. 编译 Libpng
echo "=== [DEBUG] Building libpng ==="
cd "$SRC/libpng"

# 禁用干扰项
if [ -f "scripts/pnglibconf.dfa" ]; then
    cat scripts/pnglibconf.dfa | \
      sed -e "s/option STDIO/option STDIO disabled/" \
          -e "s/option WARNING /option WARNING disabled/" \
          -e "s/option WRITE enables WRITE_INT_FUNCTIONS/option WRITE disabled/" \
    > scripts/pnglibconf.dfa.temp
    mv scripts/pnglibconf.dfa.temp scripts/pnglibconf.dfa
fi

autoreconf -f -i

# 配置
./configure --with-libpng-prefix=OSS_FUZZ_ \
            --enable-static \
            --disable-shared \
            --with-zlib-prefix="$SRC/zlib"

# 【核心修复】
# 不再运行 make clean，也不指定 libpng16.la
# 直接运行 make，让它构建默认目标
echo "Running make..."
make -j$(nproc)

# 3. 链接 Fuzzer
echo "=== [DEBUG] Linking fuzzer binary ==="

# 查找静态库 (.libs 是 libtool 的默认隐藏目录)
if [ -f ".libs/libpng16.a" ]; then
    LIBPNG_A=".libs/libpng16.a"
else
    # 备用方案，万一不在 .libs 下
    LIBPNG_A="libpng16.a"
fi
echo "Found libpng at: $LIBPNG_A"

# 检查 Fuzzer 源码
if [ -f "contrib/oss-fuzz/libpng_read_fuzzer.cc" ]; then
    FUZZER_SRC="contrib/oss-fuzz/libpng_read_fuzzer.cc"
else
    echo "WARNING: Fuzzer source not found, downloading fallback..."
    wget -q https://raw.githubusercontent.com/glennrp/libpng/libpng16/contrib/oss-fuzz/libpng_read_fuzzer.cc
    FUZZER_SRC="libpng_read_fuzzer.cc"
fi

# 链接
$CXX $CXXFLAGS -std=c++11 -I. -I"$SRC/zlib" \
     "$FUZZER_SRC" \
     -o "$OUT/libpng_read_fuzzer" \
     "$LIBPNG_A" "$SRC/zlib/libz.a" \
     $LIB_FUZZING_ENGINE

# 4. 复制字典
echo "=== [DEBUG] Packaging ==="
cp "$SRC"/*.dict "$OUT/" || true
find . -name "*.png" | zip -q -j "$OUT/libpng_read_fuzzer_seed_corpus.zip" -@ || echo "Seeds skipped"

echo "=== [DEBUG] Build Finished Successfully ==="
