#!/bin/bash
echo "=========================================="
echo "🔧 XRAM完整优化配置脚本 (Debian 11专用)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查root权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用sudo运行此脚本${NC}"
    exit 1
fi

# 函数：输出带颜色的信息
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. 系统状态检查
info "检查系统状态..."
echo "------------------------------------------"
echo "内存: $(free -h | grep Mem | awk '{print $2}')"
echo "当前Swap: $(swapon --show | wc -l) 个设备"
echo "负载: $(cat /proc/loadavg | awk '{print $1}')"
echo "------------------------------------------"

# 检查是否有活跃的采集任务
if pgrep -f "python.*采集" > /dev/null; then
    warn "检测到Python采集任务正在运行"
    read -p "是否继续优化? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        info "已取消执行"
        exit 0
    fi
fi

# 2. 停止现有swap（安全方式）
info "安全停止现有swap..."
swapoff -a 2>/dev/null
sleep 2

# 3. 加载xram模块
info "加载XRAM模块..."
modprobe xram 2>/dev/null || {
    warn "xram模块加载失败，尝试zram..."
    modprobe zram 2>/dev/null || {
        error "无法加载xram/zram模块，可能内核不支持"
        exit 1
    }
    # 如果zram加载成功，创建符号链接
    if [ ! -e /dev/xram0 ] && [ -e /dev/zram0 ]; then
        warn "使用zram设备，创建xram符号链接"
        ln -sf /dev/zram0 /dev/xram0
    fi
}

# 4. 确定实际设备名称
if [ -e /dev/xram0 ]; then
    RAM_DEVICE="xram0"
    info "使用XRAM设备: /dev/xram0"
elif [ -e /dev/zram0 ]; then
    RAM_DEVICE="zram0"
    info "使用ZRAM设备: /dev/zram0"
else
    error "未找到xram/zram设备"
    exit 1
fi

# 5. 配置XRAM参数
info "配置XRAM参数..."
echo "lz4" > /sys/block/${RAM_DEVICE}/comp_algorithm 2>/dev/null || warn "无法设置压缩算法，使用默认值"
echo "1536M" > /sys/block/${RAM_DEVICE}/disksize 2>/dev/null || {
    error "无法设置XRAM大小"
    exit 1
}

# 6. 启用XRAM
info "启用XRAM..."
mkswap /dev/${RAM_DEVICE} >/dev/null 2>&1
swapon /dev/${RAM_DEVICE} || {
    error "启用XRAM失败"
    exit 1
}

# 7. 创建智能启动脚本
info "创建持久化启动脚本..."
cat > /usr/local/bin/xram-manager.sh << 'EOF'
#!/bin/bash
# XRAM智能管理脚本

RAM_DEVICE=""
if [ -e /dev/xram0 ]; then
    RAM_DEVICE="xram0"
elif [ -e /dev/zram0 ]; then
    RAM_DEVICE="zram0"
else
    echo "未找到XRAM/ZRAM设备"
    exit 1
fi

case "$1" in
    start)
        if swapon --show | grep -q ${RAM_DEVICE}; then
            echo "XRAM已经启用"
            exit 0
        fi
        
        modprobe ${RAM_DEVICE%%0} 2>/dev/null
        echo "lz4" > /sys/block/${RAM_DEVICE}/comp_algorithm 2>/dev/null
        echo "1536M" > /sys/block/${RAM_DEVICE}/disksize 2>/dev/null
        mkswap /dev/${RAM_DEVICE} >/dev/null 2>&1
        swapon /dev/${RAM_DEVICE} && echo "XRAM启动成功" || echo "XRAM启动失败"
        ;;
    stop)
        swapoff /dev/${RAM_DEVICE} 2>/dev/null && echo "XRAM已停止" || echo "XRAM停止失败"
        ;;
    status)
        echo "=== XRAM状态 ==="
        swapon --show | grep ${RAM_DEVICE}
        echo "=== 设备信息 ==="
        if [ -e /sys/block/${RAM_DEVICE}/disksize ]; then
            echo "大小: $(cat /sys/block/${RAM_DEVICE}/disksize) bytes"
            echo "压缩算法: $(cat /sys/block/${RAM_DEVICE}/comp_algorithm)"
        else
            echo "设备不存在"
        fi
        ;;
    *)
        echo "用法: $0 {start|stop|status}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/xram-manager.sh

# 8. 创建Systemd服务
info "配置Systemd服务..."
cat > /etc/systemd/system/xram-optimized.service << EOF
[Unit]
Description=Optimized XRAM Configuration
After=multi-user.target
Before=swap.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/xram-manager.sh start
ExecStop=/usr/local/bin/xram-manager.sh stop
ExecReload=/bin/bash -c "/usr/local/bin/xram-manager.sh stop && sleep 2 && /usr/local/bin/xram-manager.sh start"

[Install]
WantedBy=multi-user.target
EOF

# 9. 优化内核参数
info "优化内核参数..."
if ! grep -q "XRAM优化参数" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'EOF'

# XRAM优化参数
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=10
vm.page-cluster=0

# 网络优化
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# IO优化
vm.dirty_writeback_centisecs=1500
vm.dirty_expire_centisecs=3000
EOF
    info "内核参数已添加"
else
    info "内核参数已存在，跳过添加"
fi

# 10. 优化IO调度器
info "优化IO调度器..."
echo 'deadline' > /sys/block/sda/queue/scheduler 2>/dev/null && info "IO调度器设置为: deadline" || warn "无法设置IO调度器"

# 创建持久化IO调度器配置
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

# 11. 启用所有服务
info "启用系统服务..."
systemctl daemon-reload
systemctl enable xram-optimized.service
systemctl enable io-optimize.service
systemctl start xram-optimized.service
systemctl start io-optimize.service

# 12. 立即生效内核参数
sysctl -p >/dev/null 2>&1

# 13. 最终验证
echo "=========================================="
info "✅ XRAM优化配置完成！"
echo "=========================================="
echo "📊 最终系统状态："
echo "------------------------------------------"
echo "内存状态:"
free -h
echo "------------------------------------------"
echo "Swap设备:"
swapon --show
echo "------------------------------------------"
echo "XRAM设备信息:"
if [ -e /sys/block/${RAM_DEVICE}/disksize ]; then
    echo "设备: /dev/${RAM_DEVICE}"
    echo "大小: $(cat /sys/block/${RAM_DEVICE}/disksize) bytes"
    echo "压缩算法: $(cat /sys/block/${RAM_DEVICE}/comp_algorithm)"
else
    error "XRAM设备信息不可读"
fi
echo "------------------------------------------"
echo "服务状态:"
systemctl status xram-optimized.service --no-pager -l | head -10
echo "------------------------------------------"
echo "🔧 管理命令:"
echo "启动XRAM: systemctl start xram-optimized.service"
echo "停止XRAM: systemctl stop xram-optimized.service"
echo "查看状态: /usr/local/bin/xram-manager.sh status"
echo "重启测试: sudo reboot"
echo "=========================================="

# 14. 创建使用说明
cat > /root/xram-usage.txt << 'EOF'
XRAM优化使用说明
================

✅ 已完成的优化：
1. XRAM内存压缩交换 (1.5G)
2. 内核参数优化
3. IO调度器优化 (deadline)
4. Systemd持久化服务

🔧 管理命令：
- 查看状态: /usr/local/bin/xram-manager.sh status
- 手动启动: systemctl start xram-optimized.service  
- 手动停止: systemctl stop xram-optimized.service
- 重启服务: systemctl restart xram-optimized.service

📊 验证命令：
- 内存状态: free -h
- Swap设备: swapon --show
- 服务状态: systemctl status xram-optimized.service

🔄 重启测试：
执行 sudo reboot 重启系统，然后检查XRAM是否自动恢复。

⚠️ 注意事项：
- 如果遇到设备忙错误，重启系统即可解决
- 采集任务运行时可能短暂影响性能
- 定期检查系统负载: cat /proc/loadavg
EOF

info "使用说明已保存到: /root/xram-usage.txt"
echo "=========================================="
info "🎯 所有优化已完成！现在可以安全重启系统。"
echo "=========================================="
