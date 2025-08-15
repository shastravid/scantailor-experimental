#!/bin/bash

# Oracle Cloud ARM64 VPS Performance Optimization Script
# Optimizes system settings for scantailor-experimental CLI performance

set -e

echo "🚀 Optimizing Oracle Cloud ARM64 VPS for ScanTailor CLI..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check ARM64 architecture
if [ "$(uname -m)" != "aarch64" ]; then
    echo "Warning: This script is optimized for ARM64 architecture"
    echo "Current: $(uname -m)"
fi

# System information
echo "📊 System Information:"
echo "  Architecture: $(uname -m)"
echo "  Kernel: $(uname -r)"
echo "  CPU cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk space: $(df -h / | tail -1 | awk '{print $4}' | sed 's/G/ GB/')"
echo ""

# Update system packages
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install performance monitoring tools
echo "🔧 Installing performance tools..."
apt-get install -y \
    htop \
    iotop \
    sysstat \
    cpufrequtils \
    linux-tools-common \
    linux-tools-generic

# Optimize CPU governor for performance
echo "⚡ Setting CPU governor to performance mode..."
echo 'performance' | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null

# Make CPU governor setting persistent
echo "📝 Making CPU governor persistent..."
cat > /etc/systemd/system/cpu-performance.service << EOF
[Unit]
Description=Set CPU governor to performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable cpu-performance.service
systemctl start cpu-performance.service

# Optimize memory settings
echo "🧠 Optimizing memory settings..."
cat >> /etc/sysctl.conf << EOF

# ARM64 Oracle Cloud optimizations for ScanTailor
# Reduce swappiness for better performance
vm.swappiness=10

# Optimize memory allocation
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Improve file system performance
vm.vfs_cache_pressure=50

# Network optimizations
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

# Apply sysctl settings
sysctl -p

# Optimize I/O scheduler for ARM64
echo "💾 Optimizing I/O scheduler..."
echo 'mq-deadline' > /sys/block/*/queue/scheduler 2>/dev/null || true

# Create swap file if not exists (for memory-intensive operations)
if [ ! -f /swapfile ]; then
    echo "💿 Creating optimized swap file..."
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Optimize for image processing workloads
echo "🖼️ Optimizing for image processing..."
# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF

# Increased limits for image processing
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Create performance monitoring script
echo "📈 Creating performance monitoring script..."
cat > /usr/local/bin/scantailor-monitor << 'EOF'
#!/bin/bash
# ScanTailor Performance Monitor

echo "=== ScanTailor Performance Monitor ==="
echo "Time: $(date)"
echo ""
echo "CPU Usage:"
top -bn1 | grep "Cpu(s)" | awk '{print $2 $3 $4 $5}'
echo ""
echo "Memory Usage:"
free -h
echo ""
echo "Disk I/O:"
iostat -x 1 1 | tail -n +4
echo ""
echo "Load Average:"
uptime
echo ""
echo "Active ScanTailor Processes:"
ps aux | grep scantailor | grep -v grep
EOF

chmod +x /usr/local/bin/scantailor-monitor

# Create optimization verification script
cat > /usr/local/bin/verify-optimizations << 'EOF'
#!/bin/bash
echo "🔍 Verifying ARM64 optimizations..."
echo ""
echo "CPU Governor:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo ""
echo "Swappiness:"
cat /proc/sys/vm/swappiness
echo ""
echo "I/O Scheduler:"
cat /sys/block/*/queue/scheduler | head -1
echo ""
echo "File Descriptor Limits:"
ulimit -n
echo ""
echo "Available Memory:"
free -h | grep Mem
EOF

chmod +x /usr/local/bin/verify-optimizations

# Install ARM64 optimized libraries
echo "📚 Installing ARM64 optimized libraries..."
apt-get install -y \
    libblas3 \
    liblapack3 \
    libatlas-base-dev \
    libomp-dev

# Create systemd service for automatic optimization on boot
cat > /etc/systemd/system/scantailor-optimize.service << EOF
[Unit]
Description=ScanTailor ARM64 Optimizations
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/verify-optimizations
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable scantailor-optimize.service

echo ""
echo "✅ Oracle Cloud ARM64 optimization completed!"
echo ""
echo "📋 Applied optimizations:"
echo "  • CPU governor set to 'performance'"
echo "  • Memory swappiness reduced to 10"
echo "  • I/O scheduler optimized for ARM64"
echo "  • File descriptor limits increased"
echo "  • 2GB swap file created"
echo "  • ARM64 optimized libraries installed"
echo ""
echo "🔧 Useful commands:"
echo "  • Monitor performance: scantailor-monitor"
echo "  • Verify optimizations: verify-optimizations"
echo "  • Check CPU frequency: cpufreq-info"
echo "  • Monitor I/O: iotop"
echo ""
echo "🔄 Reboot recommended to ensure all optimizations are active."