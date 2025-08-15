#!/bin/bash

# ARM64 Ubuntu 22.04 Optimized Build Script for ScanTailor CLI
# Designed for Oracle Cloud VPS without GPU
# Enhanced with Oracle Cloud specific optimizations

set -e

echo "🚀 Building ScanTailor CLI for ARM64 Ubuntu 22.04 (Oracle Cloud Optimized)..."

# Check if running on ARM64
if [ "$(uname -m)" != "aarch64" ]; then
    echo "Warning: This script is optimized for ARM64 architecture"
    echo "Current architecture: $(uname -m)"
fi

# Detect Oracle Cloud environment
if [ -f /sys/hypervisor/uuid ] && grep -q "oracle" /sys/hypervisor/uuid 2>/dev/null; then
    echo "🌩️ Oracle Cloud environment detected"
    ORACLE_CLOUD=true
else
    echo "🖥️ Generic ARM64 environment"
    ORACLE_CLOUD=false
fi

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install build dependencies with ARM64 optimized packages
echo "🔧 Installing build dependencies..."
sudo apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    qt6-base-dev \
    qt6-tools-dev \
    qt6-base-dev-tools \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    libeigen3-dev \
    pkg-config \
    libboost-dev \
    git \
    libblas3 \
    liblapack3 \
    libatlas-base-dev \
    libomp-dev \
    ccache

# Setup ccache for faster rebuilds
echo "⚡ Setting up ccache for faster builds..."
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache --max-size=2G

# Create build directory
echo "📁 Creating build directory..."
rm -rf build-arm64-server
mkdir -p build-arm64-server
cd build-arm64-server

# Oracle Cloud specific CPU detection and optimization
CPU_FLAGS="-march=armv8-a -mtune=cortex-a72"
if [ "$ORACLE_CLOUD" = true ]; then
    # Oracle Cloud uses Ampere Altra processors
    CPU_FLAGS="-march=armv8.2-a -mtune=neoverse-n1"
    echo "🔧 Using Oracle Cloud Ampere Altra optimizations"
fi

# Configure with ARM64 optimizations
echo "⚙️ Configuring build with ARM64 optimizations..."
cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_C_FLAGS="$CPU_FLAGS -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer -flto" \
    -DCMAKE_CXX_FLAGS="$CPU_FLAGS -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer -flto -std=c++17" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto -Wl,--gc-sections -Wl,--strip-all" \
    -DENABLE_OPENCL=OFF \
    -DENABLE_OPENGL=OFF \
    -DBUILD_CRASH_REPORTER=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_SKIP_RPATH=ON \
    -DBUILD_TESTING=OFF \
    -DQT_NO_DEBUG_OUTPUT=ON \
    -DQT_NO_WARNING_OUTPUT=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

# Optimize build parallelism for Oracle Cloud
CPU_CORES=$(nproc)
if [ "$ORACLE_CLOUD" = true ]; then
    # Oracle Cloud ARM instances have good memory, use all cores
    BUILD_JOBS=$(nproc)
else
    # Use 75% of available cores to avoid overwhelming the VPS
    BUILD_JOBS=$((CPU_CORES * 3 / 4))
    if [ $BUILD_JOBS -lt 1 ]; then
        BUILD_JOBS=1
    fi
fi

# Build with optimal job count for ARM64
echo "🔨 Building (using $BUILD_JOBS parallel jobs)..."
ninja -j$BUILD_JOBS

# Strip binary to reduce size
echo "✂️ Stripping binary..."
strip scantailor-experimental-cli

# Verify the build
echo "Verifying build..."
file scantailor-experimental-cli
ldd scantailor-experimental-cli

# Display build information
echo ""
echo "✅ Build completed successfully!"
echo "📊 Build information:"
echo "  Binary: $(pwd)/scantailor-experimental-cli"
echo "  Size: $(du -h scantailor-experimental-cli | cut -f1)"
echo "  Architecture: $(file scantailor-experimental-cli | grep -o 'ARM aarch64')"
echo "  CPU Flags: $CPU_FLAGS"
echo "  Oracle Cloud: $ORACLE_CLOUD"
echo ""
echo "🧪 Testing binary..."
if ./scantailor-experimental-cli --help > /dev/null 2>&1; then
    echo "✅ Binary test passed!"
else
    echo "❌ Binary test failed!"
    exit 1
fi

# Performance benchmark
echo ""
echo "📈 Running quick performance test..."
time ./scantailor-experimental-cli --help > /dev/null 2>&1

echo ""
echo "🎉 ARM64 optimized ScanTailor CLI is ready!"
echo "📍 Location: $(pwd)/scantailor-experimental-cli"
echo ""
echo "💡 Usage examples:"
echo "  ./scantailor-experimental-cli --help"
echo "  ./scantailor-experimental-cli input_dir output_dir"
echo ""
echo "🚀 For optimal performance on Oracle Cloud, run:"
echo "  sudo ../optimize_oracle_arm64.sh"
echo ""
echo "📊 ccache statistics:"
ccache -s