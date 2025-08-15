# ScanTailor Experimental CLI - Safe Build Instructions

This document provides instructions for building and running the CLI version of scantailor-experimental without segmentation faults.

## Problem Description

The segmentation fault you're experiencing is likely caused by:
1. **OpenCL initialization issues** on headless servers
2. **Missing GPU drivers** or OpenCL runtime
3. **Acceleration provider failures** during initialization

## Solution 1: Safe Build (Recommended)

Use the provided safe build script that disables problematic features:

```bash
# Make the script executable
chmod +x build_cli_safe.sh

# Run the safe build
./build_cli_safe.sh

# Test the CLI
cd build-cli-safe
./scantailor-experimental-cli --help
```

## Solution 2: Manual CMake Configuration

If you prefer manual configuration:

```bash
mkdir -p build-cli-manual
cd build-cli-manual

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_OPENCL=OFF \
    -DENABLE_OPENGL=OFF \
    -DBUILD_CRASH_REPORTER=OFF

make -j$(nproc)
```

## Solution 3: Apply Code Patch

If you want to keep acceleration features but add safety checks:

```bash
# Apply the segfault fix patch
patch -p1 < segfault_fix.patch

# Build normally
mkdir -p build-cli-patched
cd build-cli-patched
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

## Testing Your Build

Test with a simple command:

```bash
./scantailor-experimental-cli \
    --verbose \
    --layout=1 \
    --layout-direction=lr \
    --deskew=auto \
    --content-detection=normal \
    --margins=72 \
    --alignment=center \
    --dpi=400 \
    --output-dpi=400 \
    --color-mode=black_and_white \
    --white-margins \
    --normalize-illumination \
    --threshold=0 \
    --despeckle=normal \
    --dewarping=off \
    --depth-perception=2.0 \
    --start-filter=1 \
    --end-filter=6 \
    /path/to/input/images \
    /path/to/output/directory
```

## Environment Requirements

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    qt6-base-dev \
    qt6-tools-dev \
    libqt6opengl6-dev \
    libtiff-dev \
    libjpeg-dev \
    libpng-dev \
    zlib1g-dev \
    libeigen3-dev
```

### CentOS/RHEL
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y \
    cmake3 \
    qt6-qtbase-devel \
    qt6-qttools-devel \
    libtiff-devel \
    libjpeg-devel \
    libpng-devel \
    zlib-devel \
    eigen3-devel
```

## Troubleshooting

### If you still get segfaults:

1. **Check dependencies:**
   ```bash
   ldd ./scantailor-experimental-cli
   ```

2. **Run with debugging:**
   ```bash
   gdb ./scantailor-experimental-cli
   (gdb) run --help
   (gdb) bt  # if it crashes
   ```

3. **Check for missing libraries:**
   ```bash
   strace ./scantailor-experimental-cli --help 2>&1 | grep -i "no such file"
   ```

4. **Disable all acceleration:**
   Set environment variable before running:
   ```bash
   export QT_OPENGL=software
   ./scantailor-experimental-cli --help
   ```

### Common Issues:

- **Qt6 not found:** Install qt6-base-dev or equivalent
- **OpenCL errors:** Use the safe build script (disables OpenCL)
- **Missing TIFF support:** Install libtiff-dev
- **Memory issues:** Ensure sufficient RAM (recommend 4GB+)

## Performance Notes

- The safe build (without OpenCL) will be slower but more stable
- For large batches, consider processing in smaller chunks
- Monitor memory usage with `htop` during processing

## Success Indicators

Your build is working correctly if:
1. `--help` command runs without segfault
2. Processing a single image completes successfully
3. Output files are generated in the specified directory

If you continue to experience issues, please provide:
1. Your OS and version
2. Qt version (`qmake --version`)
3. CMake version (`cmake --version`)
4. Full error output with `--verbose` flag