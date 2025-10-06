ZRAM-standard一键命令：
```
bash <(curl -sL https://raw.githubusercontent.com/ldg118/xram-zram/refs/heads/main/zram-standard.sh)
```
XRAM-complete一键命令：
```
bash <(curl -sL https://raw.githubusercontent.com/ldg118/xram-zram/refs/heads/main/xram-complete.sh)
```

# zram-standard

✅ 这个脚本的特点
完全使用标准ZRAM - 不再使用xram

自动清理旧配置 - 移除所有xram相关配置

完整的错误处理 - 每个步骤都有错误检查

持久化配置 - Systemd服务确保重启后自动恢复

内核参数优化 - 针对ZRAM优化内存使用

IO调度器优化 - 提升磁盘性能

#  ZRAM完全清除命令
1. 完全清除ZRAM配置
```
#!/bin/bash
echo "=== 完全清除ZRAM配置 ==="

# 停止所有ZRAM相关服务
sudo systemctl stop zram-manual.service 2>/dev/null
sudo systemctl stop zram-standard.service 2>/dev/null
sudo systemctl stop zram-optimized.service 2>/dev/null
sudo systemctl stop zramswap.service 2>/dev/null
sudo systemctl stop zram-ensure.service 2>/dev/null
sudo systemctl stop zram-custom.service 2>/dev/null
sudo systemctl stop zram-smart.service 2>/dev/null
sudo systemctl stop io-optimize.service 2>/dev/null

# 禁用所有ZRAM相关服务
sudo systemctl disable zram-manual.service 2>/dev/null
sudo systemctl disable zram-standard.service 2>/dev/null
sudo systemctl disable zram-optimized.service 2>/dev/null
sudo systemctl disable zramswap.service 2>/dev/null
sudo systemctl disable zram-ensure.service 2>/dev/null
sudo systemctl disable zram-custom.service 2>/dev/null
sudo systemctl disable zram-smart.service 2>/dev/null
sudo systemctl disable io-optimize.service 2>/dev/null

# 删除所有服务文件
sudo rm -f /etc/systemd/system/zram-*.service 2>/dev/null
sudo rm -f /etc/systemd/system/io-optimize.service 2>/dev/null

# 删除所有脚本文件
sudo rm -f /usr/local/bin/zram-*.sh 2>/dev/null
sudo rm -f /usr/local/bin/xram-*.sh 2>/dev/null
sudo rm -f /usr/local/bin/check-zram.sh 2>/dev/null
sudo rm -f /root/zram-usage.txt 2>/dev/null
sudo rm -f /root/test-zram.sh 2>/dev/null

# 停止所有ZRAM交换
sudo swapoff /dev/zram0 2>/dev/null
sudo swapoff /dev/xram0 2>/dev/null
sudo swapoff -a 2>/dev/null

# 移除ZRAM模块
sudo modprobe -r zram 2>/dev/null
sudo modprobe -r xram 2>/dev/null

# 重新加载systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 恢复默认IO调度器
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler 2>/dev/null

echo "✅ ZRAM配置已完全清除"
echo "当前内存状态:"
free -h
```
2. 一键清除命令
```
# 单行命令执行清除
sudo systemctl stop zram-manual.service zram-standard.service zram-optimized.service zramswap.service zram-ensure.service zram-custom.service zram-smart.service io-optimize.service 2>/dev/null; \
sudo systemctl disable zram-manual.service zram-standard.service zram-optimized.service zramswap.service zram-ensure.service zram-custom.service zram-smart.service io-optimize.service 2>/dev/null; \
sudo rm -f /etc/systemd/system/zram-*.service /etc/systemd/system/io-optimize.service 2>/dev/null; \
sudo rm -f /usr/local/bin/zram-*.sh /usr/local/bin/xram-*.sh /usr/local/bin/check-zram.sh 2>/dev/null; \
sudo rm -f /root/zram-usage.txt /root/test-zram.sh 2>/dev/null; \
sudo swapoff /dev/zram0 /dev/xram0 2>/dev/null; sudo swapoff -a; \
sudo modprobe -r zram xram 2>/dev/null; \
sudo systemctl daemon-reload; sudo systemctl reset-failed; \
echo 'mq-deadline' | sudo tee /sys/block/sda/queue/scheduler 2>/dev/null; \
echo "✅ ZRAM完全清除完成"; free -h
```
3. 选择性清除
只清除服务和交换（保留配置）：
```
sudo systemctl stop zram-manual.service zram-standard.service zram-optimized.service zramswap.service
sudo systemctl disable zram-manual.service zram-standard.service zram-optimized.service zramswap.service
sudo swapoff /dev/zram0 2>/dev/null
sudo swapoff -a
sudo systemctl daemon-reload
free -h
```
只删除服务文件：
```
sudo rm -f /etc/systemd/system/zram-*.service
sudo systemctl daemon-reload
```
只停止ZRAM交换：
```
sudo swapoff /dev/zram0 2>/dev/null
echo "ZRAM交换已停止:"
free -h
```
4. 卸载zram-tools包
```
# 完全卸载zram-tools
sudo apt remove --purge -y zram-tools
sudo apt autoremove -y

# 清理配置
sudo rm -f /etc/default/zramswap
sudo rm -f /etc/modules-load.d/zram.conf 2>/dev/null

```
5. 清除内核参数优化

```
# 移除ZRAM相关的内核参数
sudo sed -i '/# ZRAM优化参数/,/net.ipv4.tcp_wmem=4096 65536 67108864/d' /etc/sysctl.conf
sudo sed -i '/# XRAM优化参数/,/vm.dirty_expire_centisecs=3000/d' /etc/sysctl.conf
sudo sed -i '/vm.swappiness=10/d' /etc/sysctl.conf
sudo sed -i '/vm.vfs_cache_pressure=50/d' /etc/sysctl.conf

# 重新加载sysctl
sudo sysctl -p

```
6. 验证清除结果
```
echo "=== 清除验证 ==="
echo "1. 服务状态:"
systemctl list-unit-files | grep -E "(zram|xram|io-optimize)"
echo "2. 脚本文件:"
ls -la /usr/local/bin/*ram*.sh 2>/dev/null || echo "无脚本文件"
echo "3. 内存状态:"
free -h
echo "4. Swap设备:"
swapon --show
echo "5. 模块状态:"
lsmod | grep -E "(zram|xram)" || echo "无ZRAM/XRAM模块"
echo "6. 设备文件:"
ls -la /dev/zram* /dev/xram* 2>/dev/null || echo "无ZRAM/XRAM设备"
```
7. 重启验证
```
# 重启系统确认清除效果
sudo reboot

# 重启后检查
free -h
swapon --show
systemctl list-unit-files | grep zram

```

 📋 注意事项
清除前确认：确保不需要ZRAM功能再执行清除

数据安全：清除不会影响已有数据，只移除交换功能

重启建议：清除后建议重启确保完全恢复

保留配置：如果以后还想用ZRAM，建议只停止服务而不是完全清除

执行这些命令后，你的系统将完全恢复到安装ZRAM优化之前的状态！








# xram-complete

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

























