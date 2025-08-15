# CI Build Fix for ScanTailor Experimental

## Problem

The GitHub Actions CI build is failing with the following error:
```
CMake Error: Could NOT find Eigen3 (missing: EIGEN3_INCLUDE_DIR EIGEN3_VERSION_OK)
(Required is at least version "2.91.0")
```

This happens because the CI environment doesn't have Eigen3 installed by default.

## Quick Fix Solutions

### Option 1: Use the Automated Script

Run the provided dependency installation script:
```bash
./install_ci_dependencies.sh
```

This script will:
- Detect your OS (Linux/macOS)
- Install all required dependencies including Eigen3
- Verify the installation
- Provide build instructions

### Option 2: Manual Installation

#### Ubuntu/Debian (GitHub Actions default)
```bash
sudo apt-get update
sudo apt-get install -y libeigen3-dev libboost-dev qt6-base-dev
```

#### CentOS/RHEL/Fedora
```bash
sudo yum install eigen3-devel boost-devel qt6-qtbase-devel
# or for newer versions:
sudo dnf install eigen3-devel boost-devel qt6-qtbase-devel
```

#### macOS
```bash
brew install eigen boost qt6
```

### Option 3: Use the GitHub Actions Workflow

The repository now includes `.github/workflows/build.yml` which:
- Automatically installs all dependencies
- Builds on Linux, macOS, and Windows
- Handles Qt6 and Qt5 compatibility
- Provides proper error handling

## Build Instructions After Dependency Installation

### Standard Build
```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### Qt6 Build (Recommended)
```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DST_USE_QT6=ON
make -j$(nproc)
```

### Ninja Build (Faster)
```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DST_USE_QT6=ON -G Ninja
ninja
```

## Troubleshooting

### If Eigen3 is still not found:

1. **Check installation paths:**
   ```bash
   find /usr -name "Eigen" -type d 2>/dev/null
   pkg-config --exists eigen3 && echo "Found" || echo "Not found"
   ```

2. **Manually specify Eigen3 path:**
   ```bash
   cmake .. -DEIGEN3_INCLUDE_DIR=/usr/include/eigen3
   ```

3. **For custom installations:**
   ```bash
   cmake .. -DCMAKE_PREFIX_PATH=/path/to/eigen3
   ```

### If Qt is not found:

1. **For Qt6:**
   ```bash
   cmake .. -DCMAKE_PREFIX_PATH="$(brew --prefix qt6)"  # macOS
   cmake .. -DCMAKE_PREFIX_PATH="/usr/lib/x86_64-linux-gnu/cmake/Qt6"  # Linux
   ```

2. **For Qt5 fallback:**
   ```bash
   cmake .. -DST_USE_QT6=OFF
   ```

## Dependencies Summary

### Required:
- **CMake** (>= 3.16)
- **Eigen3** (>= 2.91.0 / 3.0)
- **Boost** (>= 1.60)
- **Qt6** (>= 6.2.2) or **Qt5** (>= 5.12)

### Image Processing:
- **libjpeg** or **libjpeg-turbo**
- **libpng**
- **libtiff**
- **zlib**

### Optional:
- **OpenCV** (for advanced image processing)
- **OpenGL** (for GPU acceleration)
- **OpenCL** (for compute acceleration)

## CI Environment Specific Notes

### GitHub Actions
- Use `ubuntu-latest` runner
- Install dependencies in workflow before cmake
- Set proper Qt6 paths
- Use Ninja for faster builds

### GitLab CI
- Use `ubuntu:latest` or specific version
- Install build-essential first
- Cache dependencies between builds

### Docker
```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential cmake ninja-build \
    libeigen3-dev libboost-dev \
    qt6-base-dev qt6-tools-dev \
    libjpeg-dev libpng-dev libtiff-dev
```

## Verification

After successful build, verify with:
```bash
./scantailor-experimental --help
ldd ./scantailor-experimental  # Check linked libraries
```

## Support

If you continue to experience build issues:
1. Check the full error log
2. Verify all dependencies are installed
3. Try the automated installation script
4. Use the provided GitHub Actions workflow as reference