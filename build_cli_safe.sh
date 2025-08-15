#!/bin/bash

# Safe build script for scantailor-experimental CLI without OpenCL
# This script builds the CLI version with OpenCL disabled to prevent segmentation faults

set -e

echo "Building scantailor-experimental CLI (safe mode - no OpenCL)..."

# Create build directory
mkdir -p build-cli-safe
cd build-cli-safe

# Configure with CMake - disable OpenCL and OpenGL
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_OPENCL=OFF \
    -DENABLE_OPENGL=OFF \
    -DBUILD_CRASH_REPORTER=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local

# Build the project
make -j$(nproc)

echo "Build completed successfully!"
echo "CLI executable: ./scantailor-experimental-cli"
echo ""
echo "Test the CLI with:"
echo "./scantailor-experimental-cli --help"