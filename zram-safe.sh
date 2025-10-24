#!/bin/bash
echo "=========================================="
echo "🔧 ZRAM自动修复脚本"
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

# 1. 诊断当前状态
info "诊断系统状态..."
echo "------------------------------------------"
echo "当前内存:"
free -h
echo "------------------------------------------"
echo "ZRAM设备状态:"
ls -la /dev/zram* 2>/dev/null || echo "无ZRAM设备"
ls -la /sys/block/zram* 2>/dev/null || echo "无ZRAM配置"
echo "------------------------------------------"
echo "zram-tools服务状态:"
systemctl status zramswap.service --no-pager -l 2>/dev/null | head -10 || echo "zramswap服务未运行"

# 2. 停止所有ZRAM相关服务
info "停止ZRAM服务..."
systemctl stop zramswap.service 2>/dev/null
systemctl stop zram-safe.service 2>/dev/null
swapoff -a 2>/dev/null
sleep 3

# 3. 重新配置zram-tools
info "重新配置zram-tools..."

# 检查zram-tools配置
if [ -f "/etc/default/zramswap" ]; then
    info "备份原配置..."
    cp /etc/default/zramswap /etc/default/zramswap.backup
    
    info "修改zram-tools配置为1.5G..."
    sed -i 's/^#*PERCENT=.*/PERCENT=150/' /etc/default/zramswap
    sed -i 's/^#*SIZE=.*/SIZE=1536M/' /etc/default/zramswap
    sed -i 's/^#*ALGO=.*/ALGO=lz4/' /etc/default/zramswap
    
    echo "当前zram-tools配置:"
    cat /etc/default/zramswap | grep -v "^#" | grep -v "^$"
else
    warn "未找到zram-tools配置，创建新配置..."
    cat > /etc/default/zramswap << 'EOF'
# ZRAM configuration
ALGO=lz4
PERCENT=150
SIZE=1536M
PRIORITY=100
EOF
fi

# 4. 重启zram-tools服务
info "启动zram-tools服务..."
systemctl daemon-reload
systemctl enable zramswap.service
systemctl start zramswap.service

sleep 5

# 5. 验证配置
info "验证ZRAM状态..."
echo "------------------------------------------"
echo "服务状态:"
systemctl status zramswap.service --no-pager -l | head -10
echo "------------------------------------------"
echo "内存状态:"
free -h
echo "------------------------------------------"
echo "Swap设备:"
swapon --show
echo "------------------------------------------"

# 6. 如果zram-tools失败，使用备用方案
if ! swapon --show | grep -q zram; then
    warn "zram-tools启动失败，使用手动配置..."
    
    # 手动配置
    swapoff -a
    modprobe -r zram 2>/dev/null
    modprobe zram
    sleep 2
    
    # 检查设备
    if [ -d "/sys/block/zram0" ]; then
        echo "lz4" > /sys/block/zram0/comp_algorithm
        echo "1536M" > /sys/block/zram0/disksize
        mkswap /dev/zram0
        swapon /dev/zram0
        
        info "手动配置完成"
        free -h
        swapon --show
    else
        error "无法创建ZRAM设备"
    fi
fi

# 7. 优化内存参数
info "优化内存参数..."
if ! grep -q "vm.swappiness=15" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'EOF'

# ZRAM内存优化
vm.swappiness=15
vm.vfs_cache_pressure=50
EOF
    sysctl -p >/dev/null 2>&1
    info "内存参数已优化"
fi

# 8. 最终状态报告
echo "=========================================="
info "✅ ZRAM修复完成！"
echo "=========================================="
echo "📊 最终状态报告:"
echo "------------------------------------------"
echo "内存: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "Swap: $(free -h | grep Swap | awk '{print $2}')"
echo "ZRAM设备: $(swapon --show | grep zram | wc -l) 个"
echo "负载: $(cat /proc/loadavg | awk '{print $1}')"
echo "------------------------------------------"

if swapon --show | grep -q zram; then
    info "🎯 ZRAM配置成功！"
    echo "重启测试: sudo reboot"
else
    error "❌ ZRAM配置失败"
    echo "请检查系统日志: journalctl -u zramswap.service"
fi
echo "=========================================="
