#!/bin/bash
echo "=========================================="
echo "🔧 ZRAM标准完整配置脚本"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    error "请使用sudo运行此脚本"
    exit 1
fi

# 1. 清理之前的XRAM配置
info "清理之前的XRAM配置..."
systemctl stop xram-optimized.service 2>/dev/null
systemctl disable xram-optimized.service 2>/dev/null
systemctl stop xram-smart.service 2>/dev/null
systemctl disable xram-smart.service 2>/dev/null
rm -f /etc/systemd/system/xram-*.service 2>/dev/null
rm -f /usr/local/bin/xram-*.sh 2>/dev/null
swapoff /dev/xram0 2>/dev/null
swapoff /dev/zram0 2>/dev/null
swapoff -a 2>/dev/null

# 2. 系统状态检查
info "检查系统状态..."
echo "------------------------------------------"
echo "内存: $(free -h | grep Mem | awk '{print $2}')"
echo "当前Swap: $(swapon --show | wc -l) 个设备"
echo "负载: $(cat /proc/loadavg | awk '{print $1}')"
echo "------------------------------------------"

# 3. 安装ZRAM工具
info "安装ZRAM工具..."
apt update
if apt install -y zram-tools 2>/dev/null; then
    info "zram-tools安装成功"
else
    warn "zram-tools安装失败，使用手动配置"
fi

# 4. 手动配置ZRAM
info "手动配置ZRAM..."

# 停止所有swap
swapoff -a 2>/dev/null
sleep 2

# 加载zram模块
info "加载ZRAM模块..."
modprobe zram
if [ $? -ne 0 ]; then
    error "无法加载zram模块，内核可能不支持"
    echo "尝试安装linux-modules-extra..."
    apt install -y linux-modules-extra-$(uname -r) 2>/dev/null
    modprobe zram
    if [ $? -ne 0 ]; then
        error "ZRAM模块加载失败，系统可能不支持内存压缩"
        exit 1
    fi
fi

# 配置ZRAM参数
info "配置ZRAM参数..."
if [ -d "/sys/block/zram0" ]; then
    echo "lz4" > /sys/block/zram0/comp_algorithm
    echo "1536M" > /sys/block/zram0/disksize
    info "ZRAM参数配置成功"
else
    error "ZRAM设备目录不存在"
    exit 1
fi

# 启用ZRAM
info "启用ZRAM..."
mkswap /dev/zram0 >/dev/null 2>&1
swapon /dev/zram0
if [ $? -eq 0 ]; then
    info "ZRAM启用成功"
else
    error "ZRAM启用失败"
    exit 1
fi

# 5. 创建Systemd服务（持久化）
info "创建Systemd持久化服务..."
cat > /etc/systemd/system/zram-manual.service << 'EOF'
[Unit]
Description=Manual ZRAM Configuration
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 5
ExecStart=/sbin/modprobe zram
ExecStart=/bin/bash -c 'echo lz4 > /sys/block/zram0/comp_algorithm'
ExecStart=/bin/bash -c 'echo 1536M > /sys/block/zram0/disksize'
ExecStart=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon /dev/zram0
ExecStop=/sbin/swapoff /dev/zram0
ExecStop=/sbin/rmmod zram

[Install]
WantedBy=multi-user.target
EOF

# 6. 优化内核参数
info "优化内核参数..."
if ! grep -q "ZRAM优化参数" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'EOF'

# ZRAM优化参数
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10

# 网络优化
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
EOF
    info "内核参数已添加"
else
    info "内核参数已存在"
fi

# 7. 优化IO调度器
info "优化IO调度器..."
echo 'deadline' > /sys/block/sda/queue/scheduler 2>/dev/null && info "IO调度器设置为: deadline"

# 创建IO调度器持久化服务
cat > /etc/systemd/system/io-optimize.service << 'EOF'
[Unit]
Description=IO Scheduler Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo deadline > /sys/block/sda/queue/scheduler'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 8. 启用所有服务
info "启用系统服务..."
systemctl daemon-reload
systemctl enable zram-manual.service
systemctl enable io-optimize.service
systemctl start zram-manual.service
systemctl start io-optimize.service

# 9. 加载模块到启动项
echo "zram" >> /etc/modules

# 10. 应用内核参数
sysctl -p >/dev/null 2>&1

# 11. 最终验证
echo "=========================================="
info "✅ ZRAM配置完成！"
echo "=========================================="
echo "📊 系统状态："
echo "------------------------------------------"
swapon --show
echo "------------------------------------------"
free -h
echo "------------------------------------------"
echo "ZRAM设备信息："
if [ -d "/sys/block/zram0" ]; then
    echo "压缩算法: $(cat /sys/block/zram0/comp_algorithm)"
    echo "ZRAM大小: $(cat /sys/block/zram0/disksize)"
else
    error "ZRAM设备信息不可读"
fi
echo "------------------------------------------"
echo "服务状态："
systemctl status zram-manual.service --no-pager -l | head -10
echo "------------------------------------------"
echo "🔧 管理命令："
echo "查看状态: free -h && swapon --show"
echo "重启服务: systemctl restart zram-manual.service"
echo "重启测试: sudo reboot"
echo "=========================================="

# 12. 创建快速检查脚本
cat > /usr/local/bin/check-zram.sh << 'EOF'
#!/bin/bash
echo "=== ZRAM状态检查 ==="
echo "内存和Swap:"
free -h
echo ""
echo "Swap设备详情:"
swapon --show
echo ""
echo "ZRAM设备信息:"
if [ -d "/sys/block/zram0" ]; then
    echo "大小: $(cat /sys/block/zram0/disksize) bytes"
    echo "压缩算法: $(cat /sys/block/zram0/comp_algorithm)"
else
    echo "ZRAM设备不存在"
fi
echo ""
echo "服务状态:"
systemctl is-active zram-manual.service
EOF
chmod +x /usr/local/bin/check-zram.sh

info "快速检查脚本: /usr/local/bin/check-zram.sh"
echo "=========================================="
info "🎯 标准ZRAM配置完成！现在可以安全重启测试。"
echo "=========================================="
