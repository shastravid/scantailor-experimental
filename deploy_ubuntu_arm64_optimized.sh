#!/bin/bash

# Complete Ubuntu ARM64 Deployment Script for ScanTailor CLI
# Optimized for Oracle Cloud VPS without GPU support
# Handles all dependencies, compilation fixes, and optimizations

set -e

echo "🚀 Complete Ubuntu ARM64 ScanTailor CLI Deployment"
echo "📍 Optimized for Oracle Cloud VPS (no GPU)"
echo ""

# Check architecture
if [ "$(uname -m)" != "aarch64" ]; then
    echo "⚠️  Warning: This script is optimized for ARM64 architecture"
    echo "Current: $(uname -m)"
fi

# Detect Oracle Cloud environment
ORACLE_CLOUD=false
if [ -f /sys/hypervisor/uuid ] && grep -q "oracle" /sys/hypervisor/uuid 2>/dev/null; then
    echo "🌩️ Oracle Cloud environment detected"
    ORACLE_CLOUD=true
else
    echo "🖥️ Generic ARM64 environment"
fi

# System update
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install comprehensive dependencies
echo "🔧 Installing complete dependency stack..."
sudo apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    ccache \
    wget \
    curl \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install Qt6 with all required components
echo "📚 Installing Qt6 complete stack..."
sudo apt-get install -y \
    qt6-base-dev \
    qt6-base-dev-tools \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-linguist-tools \
    libqt6core6 \
    libqt6gui6 \
    libqt6widgets6 \
    libqt6xml6 \
    libqt6network6 \
    libqt6printsupport6 \
    qt6-qmake \
    qmake6

# Install image processing libraries
echo "🖼️ Installing image processing libraries..."
sudo apt-get install -y \
    libtiff-dev \
    libtiff6 \
    libjpeg-dev \
    libjpeg8-dev \
    libpng-dev \
    libpng16-16 \
    zlib1g-dev \
    zlib1g

# Install mathematical libraries
echo "🧮 Installing mathematical libraries..."
sudo apt-get install -y \
    libeigen3-dev \
    libboost-dev \
    libboost-test-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libblas3 \
    liblapack3 \
    libatlas-base-dev \
    libomp-dev

# Setup ccache
echo "⚡ Configuring ccache..."
export PATH="/usr/lib/ccache:$PATH"
export CCACHE_DIR="$HOME/.ccache"
ccache --max-size=2G
ccache --zero-stats

# Create optimized build directory
echo "📁 Preparing build environment..."
rm -rf build-ubuntu-arm64-optimized
mkdir -p build-ubuntu-arm64-optimized
cd build-ubuntu-arm64-optimized

# Detect CPU and set optimization flags
CPU_FLAGS="-march=armv8-a -mtune=cortex-a72"
if [ "$ORACLE_CLOUD" = true ]; then
    # Oracle Cloud uses Ampere Altra processors
    CPU_FLAGS="-march=armv8.2-a -mtune=neoverse-n1"
    echo "🔧 Oracle Cloud Ampere Altra optimizations enabled"
fi

# Set Qt6 paths explicitly
export Qt6_DIR="/usr/lib/aarch64-linux-gnu/cmake/Qt6"
export QT_SELECT=6
export CMAKE_PREFIX_PATH="/usr/lib/aarch64-linux-gnu/cmake/Qt6:/usr/lib/aarch64-linux-gnu/cmake/Qt6Core:/usr/lib/aarch64-linux-gnu/cmake/Qt6Gui:/usr/lib/aarch64-linux-gnu/cmake/Qt6Widgets:/usr/lib/aarch64-linux-gnu/cmake/Qt6Xml"

echo "🔧 Qt6 Configuration:"
echo "  Qt6_DIR: $Qt6_DIR"
echo "  CMAKE_PREFIX_PATH: $CMAKE_PREFIX_PATH"
echo ""

# Configure with comprehensive ARM64 optimizations
echo "⚙️ Configuring build with ARM64 optimizations..."
cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_C_FLAGS="$CPU_FLAGS -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer -flto -pipe" \
    -DCMAKE_CXX_FLAGS="$CPU_FLAGS -O3 -DNDEBUG -ffast-math -funroll-loops -fomit-frame-pointer -flto -pipe -std=c++17" \
    -DCMAKE_EXE_LINKER_FLAGS="-flto -Wl,--gc-sections -Wl,--strip-all -Wl,--as-needed" \
    -DCMAKE_SHARED_LINKER_FLAGS="-flto -Wl,--gc-sections -Wl,--as-needed" \
    -DST_ARCH=ARM \
    -DST_USE_QT6=ON \
    -DENABLE_OPENCL=OFF \
    -DENABLE_OPENGL=OFF \
    -DBUILD_CRASH_REPORTER=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_SKIP_RPATH=ON \
    -DBUILD_TESTING=OFF \
    -DST_NO_TESTS=ON \
    -DQT_NO_DEBUG_OUTPUT=ON \
    -DQT_NO_WARNING_OUTPUT=ON \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH" \
    -DQt6_DIR="$Qt6_DIR" \
    -DCMAKE_FIND_ROOT_PATH="/usr/lib/aarch64-linux-gnu" \
    -DCMAKE_VERBOSE_MAKEFILE=ON

echo ""
echo "📊 Build configuration completed"
echo ""

# Determine optimal build parallelism
CPU_CORES=$(nproc)
if [ "$ORACLE_CLOUD" = true ]; then
    # Oracle Cloud ARM instances have good memory
    BUILD_JOBS=$CPU_CORES
else
    # Conservative approach for other VPS
    BUILD_JOBS=$((CPU_CORES * 3 / 4))
    if [ $BUILD_JOBS -lt 1 ]; then
        BUILD_JOBS=1
    fi
fi

echo "🔨 Building with $BUILD_JOBS parallel jobs..."
echo "💾 Available memory: $(free -h | grep Mem | awk '{print $7}' | sed 's/Gi/ GB/')"
echo ""

# Build with progress monitoring
time ninja -j$BUILD_JOBS -v

echo ""
echo "✂️ Optimizing binary..."
# Strip debug symbols and optimize
strip --strip-all scantailor-experimental-cli
strip --remove-section=.comment scantailor-experimental-cli
strip --remove-section=.note scantailor-experimental-cli

# Verify build
echo "🔍 Verifying build..."
echo "Binary info:"
file scantailor-experimental-cli
echo ""
echo "Size: $(du -h scantailor-experimental-cli | cut -f1)"
echo ""
echo "Dependencies:"
ldd scantailor-experimental-cli
echo ""

# Test binary functionality
echo "🧪 Testing binary..."
if timeout 10s ./scantailor-experimental-cli --help > /dev/null 2>&1; then
    echo "✅ Binary test passed!"
else
    echo "❌ Binary test failed or timed out!"
    echo "Attempting basic execution test..."
    if ./scantailor-experimental-cli 2>&1 | grep -q "ScanTailor\|Usage\|help"; then
        echo "✅ Basic execution test passed!"
    else
        echo "❌ Binary appears to be non-functional"
        exit 1
    fi
fi

# Create installation package
echo "📦 Creating installation package..."
mkdir -p ../dist/usr/local/bin
cp scantailor-experimental-cli ../dist/usr/local/bin/
chmod +x ../dist/usr/local/bin/scantailor-experimental-cli

# Create installation script
cat > ../dist/install.sh << 'EOF'
#!/bin/bash
echo "Installing ScanTailor CLI for Ubuntu ARM64..."
sudo cp usr/local/bin/scantailor-experimental-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/scantailor-experimental-cli
echo "✅ Installation complete!"
echo "Usage: scantailor-experimental-cli --help"
EOF
chmod +x ../dist/install.sh

# Create uninstall script
cat > ../dist/uninstall.sh << 'EOF'
#!/bin/bash
echo "Uninstalling ScanTailor CLI..."
sudo rm -f /usr/local/bin/scantailor-experimental-cli
echo "✅ Uninstallation complete!"
EOF
chmod +x ../dist/uninstall.sh

# Create performance test script
cat > ../dist/performance_test.sh << 'EOF'
#!/bin/bash
echo "ScanTailor CLI Performance Test"
echo "=============================="
echo "System: $(uname -a)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo ""
echo "Testing binary startup time..."
time ./usr/local/bin/scantailor-experimental-cli --help > /dev/null 2>&1
echo ""
echo "Testing help output..."
./usr/local/bin/scantailor-experimental-cli --help
EOF
chmod +x ../dist/performance_test.sh

# Create README
cat > ../dist/README.md << 'EOF'
# ScanTailor Experimental CLI - Ubuntu ARM64 Optimized

## Overview
This is an optimized build of ScanTailor CLI specifically designed for Ubuntu ARM64 systems, particularly Oracle Cloud VPS instances without GPU support.

## Features
- ARM64 native compilation with Ampere Altra optimizations
- Qt6 based for modern compatibility
- No GPU dependencies (OpenGL/OpenCL disabled)
- Optimized for server environments
- Memory efficient processing

## Installation
```bash
./install.sh
```

## Usage
```bash
scantailor-experimental-cli --help
scantailor-experimental-cli input_directory output_directory
```

## Performance Testing
```bash
./performance_test.sh
```

## Uninstallation
```bash
./uninstall.sh
```

## System Requirements
- Ubuntu 20.04+ ARM64
- Qt6 libraries
- 2GB+ RAM recommended
- ARM64 processor (optimized for Ampere Altra)

## Build Information
- Compiler: GCC with ARM64 optimizations
- Qt Version: 6.x
- Architecture: ARM64 (aarch64)
- Optimizations: -O3, LTO, fast-math
EOF

# Performance benchmark
echo "📈 Running performance benchmark..."
echo "Startup time test:"
time ./scantailor-experimental-cli --help > /dev/null 2>&1
echo ""

# Display final results
echo "🎉 Ubuntu ARM64 optimized build completed successfully!"
echo ""
echo "📊 Build Summary:"
echo "  Binary: $(pwd)/scantailor-experimental-cli"
echo "  Size: $(du -h scantailor-experimental-cli | cut -f1)"
echo "  Architecture: $(file scantailor-experimental-cli | grep -o 'ARM aarch64')"
echo "  CPU Flags: $CPU_FLAGS"
echo "  Oracle Cloud: $ORACLE_CLOUD"
echo "  Build Jobs: $BUILD_JOBS"
echo ""
echo "📦 Distribution Package: ../dist/"
echo "  - install.sh (installation script)"
echo "  - uninstall.sh (removal script)"
echo "  - performance_test.sh (benchmark tool)"
echo "  - README.md (documentation)"
echo ""
echo "🚀 Quick Installation:"
echo "  cd ../dist && ./install.sh"
echo ""
echo "💡 Usage Examples:"
echo "  scantailor-experimental-cli --help"
echo "  scantailor-experimental-cli /path/to/scans /path/to/output"
echo ""
echo "📊 ccache statistics:"
ccache -s
echo ""
echo "✅ Deployment complete! Ready for production use."