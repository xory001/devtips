#!/bin/bash
# xory.zhu, 2025.12.07
# 扩展嵌入式 linux 系统的 rootfs 分区到磁盘末尾
# 使用前通过 lsblk 确定 rootfs 分区，修改 DISK 和 PART_NUM

# 拷贝到 /usr/local/bin/expand-rootfs.sh
# 编辑 sudo nano /etc/rc.local
# 加上 & 符号让它在后台运行，避免阻塞系统启动（虽然扩容很快，但后台运行更安全）
# /usr/local/bin/expand-rootfs.sh &
#
# exit 0
#
# 如果没有 growpart，安装 cloud-guest-utils 工具包
# 或者使用 parted
# parted [设备名] resizepart [分区号] 100%
# 注意：这里是设备名 /dev/sda，不是分区名 sda2
# "2" 代表第2个分区
# "100%" 代表扩展到磁盘末尾
# sudo parted /dev/sda resizepart 2 100%
# 修改分区表后，还需要拉伸文件系统才能真正用上空间
# 如果是 ext4 (绝大多数情况)
# sudo resize2fs /dev/sda2

# 如果是 xfs
# sudo xfs_growfs /dev/sda2

set -e # 遇到错误立即退出

DISK="/dev/mmcblk0"       # 要备份的目标 (eMMC)
PART_NUM="2"              # rootfs 分区号
PART_DEV="${DISK}p${PART_NUM}"

DONE_PATH=/var/lib/misc
DONE_FLAG=${DONE_PATH}/expanded

# 定义日志文件
LOGFILE="/var/log/first_boot_setup.log"

# 增加 PATH，防止 rc.local 环境下找不到命令
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 检查标志文件，如果存在说明已经执行过，直接退出
if [ -f $DONE_FLAG ]; then
    exit 0
fi

# --- 开始执行首次启动逻辑 ---
echo "$(date): First boot detected. Starting setup..." > $LOGFILE

# 1. 自动扩容 Rootfs
echo "[1/3] Expanding rootfs..." >> $LOGFILE
if command -v growpart &> /dev/null; then
    # 假设 rootfs 是第 2 个分区 (请根据你的实际情况修改，如 2 或 9)
    growpart $DISK $PART_NUM >> $LOGFILE 2>&1
    partprobe $DISK >> $LOGFILE 2>&1
    sleep 1
    resize2fs $PART_DEV >> $LOGFILE 2>&1
else
    echo "Error: growpart not found." >> $LOGFILE
fi

## 2. 重置 Machine-ID (防止 IP 冲突)
#echo "[2/3] Resetting Machine-ID..." >> $LOGFILE
#rm -f /etc/machine-id
#rm -f /var/lib/dbus/machine-id
#dbus-uuidgen --ensure
#systemd-machine-id-setup >> $LOGFILE 2>&1

## 3. 设置唯一 Hostname (基于 MAC 后四位)
#echo "[3/3] Setting unique hostname..." >> $LOGFILE
#CURRENT_MAC=$(cat /sys/class/net/eth0/address 2>/dev/null)
#if [ -n "$CURRENT_MAC" ]; then
#    SUFFIX=$(echo $CURRENT_MAC | awk -F: '{print $5$6}')
#    NEW_HOSTNAME="lubancat-$SUFFIX"
#    echo "New Hostname: $NEW_HOSTNAME" >> $LOGFILE
#    hostnamectl set-hostname "$NEW_HOSTNAME"
#    sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
#fi

# 4. 完成标记
mkdir -p $DONE_PATH
touch $DONE_FLAG
echo "$(date): Setup completed." >> $LOGFILE

exit 0
