#!/bin/bash

# ARM64 Oracle Cloud Deployment Summary Script
# Quick overview and deployment options for ScanTailor CLI

set -e

echo "🌩️ ScanTailor Experimental - Oracle Cloud ARM64 Deployment Summary"
echo "================================================================="
echo ""

# System information
echo "📊 System Information:"
echo "  Architecture: $(uname -m)"
echo "  OS: $(lsb_release -d | cut -f2)"
echo "  Kernel: $(uname -r)"
echo "  CPU cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk space: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

# Check if Oracle Cloud
if [ -f /sys/hypervisor/uuid ] && grep -q "oracle" /sys/hypervisor/uuid 2>/dev/null; then
    echo "🌩️ Oracle Cloud environment detected"
    ORACLE_CLOUD=true
else
    echo "🖥️ Generic ARM64 environment"
    ORACLE_CLOUD=false
fi
echo ""

# Available deployment methods
echo "🚀 Available Deployment Methods:"
echo ""
echo "1. 📦 Automated Build Script (Recommended)"
echo "   ./build_arm64_ubuntu.sh"
echo "   • Detects Oracle Cloud automatically"
echo "   • Applies ARM64 optimizations"
echo "   • Uses ccache for faster rebuilds"
echo "   • Includes performance testing"
echo ""
echo "2. 🐳 Docker Deployment"
echo "   docker build -f Dockerfile.arm64 -t scantailor-arm64 ."
echo "   • Containerized deployment"
echo "   • Multi-stage build optimization"
echo "   • Security hardened"
echo "   • Easy scaling"
echo ""
echo "3. ⚙️ Manual CMake Build"
echo "   cmake .. -C cmake_arm64_server.cmake -GNinja"
echo "   • Full control over build options"
echo "   • Custom optimization flags"
echo "   • Development-friendly"
echo ""
echo "4. ⚡ System Optimization"
echo "   sudo ./optimize_oracle_arm64.sh"
echo "   • CPU governor optimization"
echo "   • Memory management tuning"
echo "   • I/O scheduler optimization"
echo "   • Performance monitoring tools"
echo ""

# Performance expectations
echo "📈 Expected Performance on Oracle Cloud ARM64:"
echo ""
if [ "$ORACLE_CLOUD" = true ]; then
    echo "  Oracle Cloud Ampere Altra Optimizations:"
    echo "  • CPU flags: -march=armv8.2-a -mtune=neoverse-n1"
    echo "  • Expected processing: 4-12 pages/min (depending on OCPUs)"
    echo "  • Memory efficiency: Optimized for Oracle Cloud architecture"
else
    echo "  Generic ARM64 Optimizations:"
    echo "  • CPU flags: -march=armv8-a -mtune=cortex-a72"
    echo "  • Expected processing: 2-8 pages/min (depending on hardware)"
    echo "  • Memory efficiency: Standard ARM64 optimizations"
fi
echo ""

# Quick start guide
echo "🎯 Quick Start Guide:"
echo ""
echo "For immediate deployment:"
echo "  1. git clone https://github.com/shastravid/scantailor-experimental.git"
echo "  2. cd scantailor-experimental"
echo "  3. ./build_arm64_ubuntu.sh"
echo "  4. sudo ./optimize_oracle_arm64.sh (optional)"
echo ""
echo "For Docker deployment:"
echo "  1. docker build -f Dockerfile.arm64 -t scantailor ."
echo "  2. docker run --rm -v input:/data/input -v output:/data/output scantailor"
echo ""

# File overview
echo "📁 ARM64 Optimization Files:"
echo ""
echo "Build Scripts:"
echo "  • build_arm64_ubuntu.sh - Main build script with Oracle Cloud detection"
echo "  • cmake_arm64_server.cmake - CMake configuration for ARM64 servers"
echo ""
echo "Deployment:"
echo "  • Dockerfile.arm64 - Multi-stage Docker build for ARM64"
echo "  • optimize_oracle_arm64.sh - System optimization script"
echo ""
echo "Documentation:"
echo "  • ORACLE_CLOUD_ARM64_DEPLOYMENT.md - Comprehensive deployment guide"
echo "  • CLI_BUILD_INSTRUCTIONS.md - General build instructions"
echo ""

# Troubleshooting
echo "🔧 Troubleshooting:"
echo ""
echo "Common issues and solutions:"
echo "  • Build failures: Check dependencies with 'apt list --installed | grep -E "(cmake|qt6|ninja)"'"
echo "  • Slow performance: Run 'sudo ./optimize_oracle_arm64.sh'"
echo "  • Memory issues: Monitor with 'free -h' and 'htop'"
echo "  • Segmentation faults: Ensure OpenCL/OpenGL are disabled"
echo ""
echo "Monitoring commands:"
echo "  • scantailor-monitor - Performance monitoring (after optimization)"
echo "  • verify-optimizations - Check applied optimizations"
echo "  • htop - Real-time system monitoring"
echo "  • iotop - I/O monitoring"
echo ""

# Next steps
echo "🎉 Next Steps:"
echo ""
if [ ! -f "build-arm64/scantailor-experimental-cli" ] && [ ! -f "build-arm64-server/scantailor-experimental-cli" ]; then
    echo "  1. Choose a deployment method above"
    echo "  2. Run the build script or Docker command"
    echo "  3. Test with: ./scantailor-experimental-cli --help"
    echo "  4. Process your first document batch"
else
    echo "  ✅ ScanTailor CLI appears to be built!"
    echo "  1. Test with: ./build-*/scantailor-experimental-cli --help"
    echo "  2. Run system optimizations: sudo ./optimize_oracle_arm64.sh"
    echo "  3. Process your document batches"
    echo "  4. Monitor performance with provided tools"
fi
echo ""
echo "📚 For detailed instructions, see:"
echo "  • ORACLE_CLOUD_ARM64_DEPLOYMENT.md"
echo "  • CLI_BUILD_INSTRUCTIONS.md"
echo ""
echo "🌟 Enjoy fast, optimized document processing on ARM64!"