#!/bin/bash
echo "=========================================="
echo "🔧 安全版ZRAM优化脚本 (无IO修改)"
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

# 1. 清理旧配置（安全方式）
info "清理旧配置..."
{
    systemctl stop zram-manual.service 2>/dev/null
    systemctl stop zram-fixed.service 2>/dev/null
    systemctl stop zram-optimized.service 2>/dev/null
    systemctl stop io-optimize.service 2>/dev/null
    systemctl disable zram-manual.service 2>/dev/null
    systemctl disable zram-fixed.service 2>/dev/null
    systemctl disable zram-optimized.service 2>/dev/null
    systemctl disable io-optimize.service 2>/dev/null
    rm -f /etc/systemd/system/zram-*.service 2>/dev/null
    rm -f /etc/systemd/system/io-optimize.service 2>/dev/null
    swapoff -a 2>/dev/null
    true
}

# 2. 系统状态检查
info "检查系统状态..."
echo "------------------------------------------"
free -h
echo "负载: $(cat /proc/loadavg | awk '{print $1}')"
echo "当前IO调度器: $(cat /sys/block/sda/queue/scheduler)"
echo "------------------------------------------"

# 3. 安装zram-tools（可选）
info "安装zram-tools..."
apt update >/dev/null 2>&1
if apt install -y zram-tools >/dev/null 2>&1; then
    info "zram-tools安装成功"
else
    warn "zram-tools安装跳过，使用手动配置"
fi

# 4. 配置ZRAM（1.5G推荐大小）
info "配置ZRAM..."

# 停止现有swap
swapoff -a 2>/dev/null
sleep 2

# 加载模块
modprobe zram 2>/dev/null || {
    error "无法加载zram模块"
    exit 1
}

# 配置参数
echo "lz4" > /sys/block/zram0/comp_algorithm 2>/dev/null || warn "压缩算法使用默认值"
echo "1536M" > /sys/block/zram0/disksize 2>/dev/null || {
    error "无法设置ZRAM大小"
    exit 1
}

# 启用ZRAM
mkswap /dev/zram0 >/dev/null 2>&1
swapon /dev/zram0 || {
    error "ZRAM启用失败"
    exit 1
}

# 5. 创建安全的Systemd服务
info "创建Systemd服务..."
cat > /etc/systemd/system/zram-safe.service << 'EOF'
[Unit]
Description=Safe ZRAM Configuration
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 10
ExecStart=/sbin/modprobe zram
ExecStart=/bin/bash -c 'echo lz4 > /sys/block/zram0/comp_algorithm'
ExecStart=/bin/bash -c 'echo 1536M > /sys/block/zram0/disksize'
ExecStart=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon /dev/zram0
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
EOF

# 6. 仅优化内存相关参数
info "优化内存参数..."
if ! grep -q "vm.swappiness=15" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'EOF'

# ZRAM内存优化参数
vm.swappiness=15
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF
    info "内存参数已添加"
else
    info "内存参数已存在"
fi

# 7. 启用服务
info "启用系统服务..."
systemctl daemon-reload
systemctl enable zram-safe.service
systemctl start zram-safe.service

# 8. 应用参数
sysctl -p >/dev/null 2>&1

# 9. 最终验证
echo "=========================================="
info "✅ 安全版ZRAM配置完成！"
echo "=========================================="
echo "📊 系统状态："
echo "------------------------------------------"
swapon --show
echo "------------------------------------------"
free -h
echo "------------------------------------------"
echo "ZRAM设备信息："
if [ -f "/sys/block/zram0/disksize" ]; then
    echo "大小: $(cat /sys/block/zram0/disksize) bytes"
fi
if [ -f "/sys/block/zram0/comp_algorithm" ]; then
    echo "压缩算法: $(cat /sys/block/zram0/comp_algorithm)"
fi
echo "------------------------------------------"
echo "IO调度器状态: $(cat /sys/block/sda/queue/scheduler | sed 's/.*\[\([^]]*\)\].*/\1/')"
echo "------------------------------------------"
echo "服务状态："
systemctl status zram-safe.service --no-pager -l | head -6
echo "=========================================="
echo "🔧 重启测试: sudo reboot"
echo "=========================================="

# 10. 创建健康检查脚本
cat > /usr/local/bin/check-system.sh << 'EOF'
#!/bin/bash
echo "=== 系统健康检查 ==="
echo "时间: $(date)"
echo "内存: $(free -h | grep Mem | awk '{print $3"/"$2" ("$3/$2*100"%)"}')"
echo "ZRAM: $(swapon --show | grep zram0 | awk '{print $3"/"$4}')"
echo "负载: $(cat /proc/loadavg)"
echo "IO调度器: $(cat /sys/block/sda/queue/scheduler | sed 's/.*\[\([^]]*\)\].*/\1/')"
echo "进程数: $(ps aux | wc -l)"
EOF
chmod +x /usr/local/bin/check-system.sh

info "健康检查脚本: /usr/local/bin/check-system.sh"
echo "=========================================="
info "🎯 配置完成！此脚本不会修改IO调度器。"
echo "=========================================="
