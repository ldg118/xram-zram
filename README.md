# ZRAMm-optimize
✅ 这个脚本的特点
完全使用标准ZRAM - 不再使用xram

自动清理旧配置 - 移除所有xram相关配置

完整的错误处理 - 每个步骤都有错误检查

持久化配置 - Systemd服务确保重启后自动恢复

内核参数优化 - 针对ZRAM优化内存使用

IO调度器优化 - 提升磁盘性能

# 彻底清理和重新配置
```
#!/bin/bash
echo "=========================================="
echo "🔧 ZRAM彻底清理和重新配置"
echo "=========================================="

# 1. 停止所有相关服务
echo "停止服务..."
systemctl stop zram-manual.service 2>/dev/null
systemctl stop zramswap.service 2>/dev/null
systemctl stop zran-manual.service 2>/dev/null
systemctl stop zranswap.service 2>/dev/null

# 2. 禁用所有相关服务
echo "禁用服务..."
systemctl disable zram-manual.service 2>/dev/null
systemctl disable zramswap.service 2>/dev/null
systemctl disable zran-manual.service 2>/dev/null
systemctl disable zranswap.service 2>/dev/null

# 3. 删除所有自定义服务文件
echo "清理服务文件..."
rm -f /etc/systemd/system/zram-*.service 2>/dev/null
rm -f /etc/systemd/system/zran-*.service 2>/dev/null

# 4. 停止所有swap
echo "停止swap..."
swapoff -a 2>/dev/null
sleep 2

# 5. 重新加载systemd
systemctl daemon-reload

# 6. 检查当前状态
echo "当前状态:"
free -h
echo "Swap设备:"
swapon --show

echo "=========================================="
echo "✅ 清理完成"
echo "=========================================="
```

===========================================================================================================================================================================================

# xram-optimize
 脚本特点
这个脚本解决了我们讨论的所有问题：

✅ 自动检测 xram/zram 设备

✅ 安全的进程检查

✅ 完整的错误处理

✅ Systemd持久化服务

✅ IO调度器优化

✅ 内核参数优化

✅ 详细的状态验证

✅ 使用说明文档

执行后你的系统就会获得完整的XRAM优化，重启也不会丢失配置！


# XRAM优化脚本清除命令
1. 完全清除命令
```
#!/bin/bash
echo "=== 完全清除XRAM配置 ==="

# 停止所有相关服务
sudo systemctl stop xram-optimized.service 2>/dev/null
sudo systemctl stop xram-smart.service 2>/dev/null
sudo systemctl stop xram-fixed.service 2>/dev/null
sudo systemctl stop xram-manual.service 2>/dev/null

# 禁用所有相关服务
sudo systemctl disable xram-optimized.service 2>/dev/null
sudo systemctl disable xram-smart.service 2>/dev/null
sudo systemctl disable xram-fixed.service 2>/dev/null
sudo systemctl disable xram-manual.service 2>/dev/null

# 删除所有服务文件
sudo rm -f /etc/systemd/system/xram-*.service 2>/dev/null

# 删除所有脚本文件
sudo rm -f /usr/local/bin/xram-*.sh 2>/dev/null
sudo rm -f /usr/local/bin/zram-*.sh 2>/dev/null

# 停止XRAM/ZRAM交换
sudo swapoff /dev/xram0 2>/dev/null
sudo swapoff /dev/zram0 2>/dev/null
sudo swapoff -a 2>/dev/null

# 重新加载systemd
sudo systemctl daemon-reload

# 重置IO调度器（可选）
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler 2>/dev/null

echo "✅ XRAM配置已完全清除"
free -h
```
2. 一键清除命令
```
# 单行命令执行
sudo systemctl stop xram-optimized.service xram-smart.service xram-fixed.service xram-manual.service 2>/dev/null; \
sudo systemctl disable xram-optimized.service xram-smart.service xram-fixed.service xram-manual.service 2>/dev/null; \
sudo rm -f /etc/systemd/system/xram-*.service 2>/dev/null; \
sudo rm -f /usr/local/bin/xram-*.sh /usr/local/bin/zram-*.sh 2>/dev/null; \
sudo swapoff /dev/xram0 /dev/zram0 2>/dev/null; sudo swapoff -a; \
sudo systemctl daemon-reload; echo "✅ XRAM清除完成"; free -h
```
3. 选择性清除
只清除服务：
```
sudo systemctl stop xram-optimized.service xram-smart.service xram-fixed.service
sudo systemctl disable xram-optimized.service xram-smart.service xram-fixed.service
sudo rm -f /etc/systemd/system/xram-*.service
sudo systemctl daemon-reload
```
只清除脚本：
```
sudo rm -f /usr/local/bin/xram-*.sh
sudo rm -f /root/xram-usage.txt
sudo rm -f /root/test-xram.sh

```
只停止XRAM交换：
```
sudo swapoff /dev/xram0 2>/dev/null
sudo swapoff /dev/zram0 2>/dev/null
free -h
```
4. 验证清除结果
```
echo "=== 清除验证 ==="
echo "服务状态:"
systemctl list-unit-files | grep xram
echo "脚本文件:"
ls -la /usr/local/bin/*ram*.sh 2>/dev/null || echo "无脚本文件"
echo "内存状态:"
free -h
echo "Swap设备:"
swapon --show
```
5. 恢复默认配置
如果需要完全恢复到原始状态：
```
# 恢复默认IO调度器
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler

# 恢复默认内核参数（可选）
sudo sed -i '/# XRAM优化参数/,/vm.dirty_expire_centisecs=3000/d' /etc/sysctl.conf
sudo sysctl -p

# 移除zram模块
sudo modprobe -r zram 2>/dev/null
sudo modprobe -r xram 2>/dev/null

echo "✅ 系统已恢复到默认配置"
```
# 使用建议

测试前备份：如果需要保留某些配置，先备份

重启验证：清除后建议重启确认效果

ZRAM保留：如果想保留ZRAM功能，不要执行swapoff命令

执行清除后，你的系统就会回到安装XRAM优化之前的状态！

























