#!/bin/bash

# ScanTailor Experimental - CI Dependencies Installation Script
# This script installs all required dependencies for building ScanTailor Experimental
# in CI environments (GitHub Actions, GitLab CI, etc.)

set -e

echo "=== ScanTailor Experimental CI Dependencies Installer ==="
echo "Installing build dependencies..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected Linux environment"
    
    # Update package lists
    sudo apt-get update
    
    # Install essential build tools
    echo "Installing build tools..."
    sudo apt-get install -y \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        git
    
    # Install Eigen3 (the missing dependency causing the build failure)
    echo "Installing Eigen3..."
    sudo apt-get install -y libeigen3-dev
    
    # Install Boost
    echo "Installing Boost..."
    sudo apt-get install -y \
        libboost-dev \
        libboost-test-dev \
        libboost-system-dev
    
    # Install Qt6 (preferred) or Qt5
    echo "Installing Qt..."
    if apt-cache show qt6-base-dev >/dev/null 2>&1; then
        echo "Installing Qt6..."
        sudo apt-get install -y \
            qt6-base-dev \
            qt6-tools-dev \
            qt6-tools-dev-tools \
            libqt6opengl6-dev \
            libqt6svg6-dev \
            qt6-l10n-tools
        export QT_VERSION=6
    else
        echo "Installing Qt5..."
        sudo apt-get install -y \
            qt5-default \
            qttools5-dev \
            qttools5-dev-tools \
            libqt5opengl5-dev \
            libqt5svg5-dev \
            qtbase5-dev
        export QT_VERSION=5
    fi
    
    # Install image processing libraries
    echo "Installing image libraries..."
    sudo apt-get install -y \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        zlib1g-dev
    
    # Optional: Install OpenCV for advanced image processing
    if apt-cache show libopencv-dev >/dev/null 2>&1; then
        echo "Installing OpenCV (optional)..."
        sudo apt-get install -y libopencv-dev
    fi
    
    # Verify Eigen3 installation
    echo "Verifying Eigen3 installation..."
    if pkg-config --exists eigen3; then
        echo "✓ Eigen3 found: $(pkg-config --modversion eigen3)"
        echo "✓ Eigen3 include dir: $(pkg-config --variable=includedir eigen3)"
    else
        echo "⚠ Eigen3 not found via pkg-config, checking manual paths..."
        if [ -d "/usr/include/eigen3" ]; then
            echo "✓ Eigen3 found at /usr/include/eigen3"
        elif [ -d "/usr/local/include/eigen3" ]; then
            echo "✓ Eigen3 found at /usr/local/include/eigen3"
        else
            echo "✗ Eigen3 not found! This will cause build failures."
            exit 1
        fi
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS environment"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Update Homebrew
    brew update
    
    # Install dependencies
    echo "Installing dependencies via Homebrew..."
    brew install \
        cmake \
        ninja \
        eigen \
        boost \
        qt6 \
        jpeg \
        libpng \
        libtiff
    
    echo "✓ macOS dependencies installed"
    
else
    echo "Unsupported OS: $OSTYPE"
    echo "Please install dependencies manually:"
    echo "- CMake (>= 3.16)"
    echo "- Eigen3 (>= 3.0)"
    echo "- Boost (>= 1.60)"
    echo "- Qt6 or Qt5"
    echo "- JPEG, PNG, TIFF libraries"
    exit 1
fi

echo ""
echo "=== Dependency Installation Complete ==="
echo "You can now build ScanTailor Experimental with:"
echo "  mkdir build && cd build"
echo "  cmake .. -DCMAKE_BUILD_TYPE=Release"
echo "  make -j\$(nproc)"
echo ""
echo "For Qt6 builds, add: -DST_USE_QT6=ON"
echo "For Ninja builds, add: -G Ninja"