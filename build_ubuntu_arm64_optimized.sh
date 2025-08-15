#!/bin/bash

# Optimized Ubuntu ARM64 CLI Build Script for ScanTailor
# Designed for Oracle Cloud VPS without GPU support
# Error-free build with all dependencies properly configured

set -e

echo "🚀 Building optimized ScanTailor CLI for Ubuntu ARM64..."

# Check architecture
if [ "$(uname -m)" != "aarch64" ]; then
    echo "Warning: This script is optimized for ARM64 architecture"
    echo "Current: $(uname -m)"
fi

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Qt6 and all required dependencies
echo "🔧 Installing Qt6 and build dependencies..."
sudo apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    libqt6core6 \
    libqt6gui6 \
    libqt6widgets6 \
    libqt6xml6 \
    libqt6network6 \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    libeigen3-dev \
    libboost-dev \
    libboost-test-dev \
    libblas3 \
    liblapack3 \
    libatlas-base-dev \
    libomp-dev \
    ccache

# Setup ccache for faster builds
echo "⚡ Setting up ccache..."
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache --max-size=2G

# Clean and create build directory
echo "📁 Preparing build directory..."
rm -rf build-ubuntu-arm64
mkdir -p build-ubuntu-arm64
cd build-ubuntu-arm64

# Detect Oracle Cloud Ampere processors
CPU_FLAGS="-march=armv8-a -mtune=cortex-a72"
if grep -q "Ampere" /proc/cpuinfo 2>/dev/null || [ -f /sys/hypervisor/uuid ] && grep -q "oracle" /sys/hypervisor/uuid 2>/dev/null; then
    CPU_FLAGS="-march=armv8.2-a -mtune=neoverse-n1"
    echo "🌩️ Oracle Cloud Ampere optimization enabled"
fi

# Configure with Qt6 and ARM64 optimizations
echo "⚙️ Configuring build..."
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
    -DST_ARCH=ARM \
    -DST_USE_QT6=ON \
    -DENABLE_OPENCL=OFF \
    -DENABLE_OPENGL=OFF \
    -DBUILD_CRASH_REPORTER=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_SKIP_RPATH=ON \
    -DBUILD_TESTING=OFF \
    -DQT_NO_DEBUG_OUTPUT=ON \
    -DQT_NO_WARNING_OUTPUT=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_PREFIX_PATH="/usr/lib/aarch64-linux-gnu/cmake/Qt6"

# Build with optimal parallelism
CPU_CORES=$(nproc)
BUILD_JOBS=$((CPU_CORES))
if [ $BUILD_JOBS -gt 8 ]; then
    BUILD_JOBS=8  # Limit to avoid memory issues
fi

echo "🔨 Building with $BUILD_JOBS parallel jobs..."
ninja -j$BUILD_JOBS

# Strip and optimize binary
echo "✂️ Optimizing binary..."
strip scantailor-experimental-cli

# Verify build
echo "🧪 Verifying build..."
file scantailor-experimental-cli
ldd scantailor-experimental-cli

# Test binary
echo "🧪 Testing binary..."
if ./scantailor-experimental-cli --help > /dev/null 2>&1; then
    echo "✅ Binary test passed!"
else
    echo "❌ Binary test failed!"
    exit 1
fi

# Create installation script
cat > install.sh << 'EOF'
#!/bin/bash
echo "Installing ScanTailor CLI..."
sudo cp scantailor-experimental-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/scantailor-experimental-cli
echo "✅ Installation complete!"
echo "Usage: scantailor-experimental-cli --help"
EOF
chmod +x install.sh

# Display results
echo ""
echo "✅ Ubuntu ARM64 optimized build completed!"
echo "📊 Build information:"
echo "  Binary: $(pwd)/scantailor-experimental-cli"
echo "  Size: $(du -h scantailor-experimental-cli | cut -f1)"
echo "  Architecture: $(file scantailor-experimental-cli | grep -o 'ARM aarch64')"
echo "  CPU Flags: $CPU_FLAGS"
echo ""
echo "🚀 Installation:"
echo "  Run: ./install.sh"
echo ""
echo "💡 Usage examples:"
echo "  ./scantailor-experimental-cli --help"
echo "  ./scantailor-experimental-cli input_dir output_dir"
echo ""
echo "📊 ccache statistics:"
ccache -s