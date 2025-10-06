#!/bin/bash
echo "=========================================="
echo "🔧 ZRAM标准配置脚本"
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

# 1. 清理xram配置
info "清理XRAM配置..."
systemctl stop xram-fixed.service 2>/dev/null
systemctl disable xram-fixed.service 2>/dev/null
rm -f /etc/systemd/system/xram-*.service 2>/dev/null
swapoff /dev/xram0 2>/dev/null
swapoff /dev/zram0 2>/dev/null

# 2. 系统状态
info "系统状态..."
free -h
echo "负载: $(cat /proc/loadavg)"

# 3. 配置标准ZRAM
info "配置标准ZRAM..."
swapoff -a
modprobe zram

if [ -d "/sys/block/zram0" ]; then
    echo "lz4" > /sys/block/zram0/comp_algorithm
    echo "1536M" > /sys/block/zram0/disksize
    mkswap /dev/zram0
    swapon /dev/zram0
    info "ZRAM配置成功"
else
    error "ZRAM设备不可用"
    exit 1
fi

# 4. 创建ZRAM服务
info "创建ZRAM服务..."
cat > /etc/systemd/system/zram-standard.service << 'EOF'
[Unit]
Description=Standard ZRAM Configuration
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 3
ExecStart=/sbin/modprobe zram
ExecStart=/bin/bash -c 'echo lz4 > /sys/block/zram0/comp_algorithm'
ExecStart=/bin/bash -c 'echo 1536M > /sys/block/zram0/disksize'
ExecStart=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon /dev/zram0
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
EOF

# 5. 启用服务
systemctl daemon-reload
systemctl enable zram-standard.service
systemctl start zram-standard.service

# 6. 验证
echo "=========================================="
info "✅ ZRAM标准配置完成！"
echo "=========================================="
swapon --show
free -h
systemctl status zram-standard.service --no-pager -l | head -10
echo "重启测试: sudo reboot"
