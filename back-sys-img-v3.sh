#!/bin/bash
# xory.zhu, 2025.12.07
# 压缩嵌入式 linux 文件系统并使用 dd 备份
# 使用前通过 lsblk 确定 rootfs 分区，修改 DISK 和 PART_NUM

set -e # 遇到错误立即退出

# ================= 配置区域 =================
DISK="/dev/mmcblk0"       # 要备份的目标 (eMMC)
PART_NUM="2"              # rootfs 分区号
BUFFER_SIZE_MB=256        # 缓冲空间
IMG_NAME="backup-$(date +%s).img"

DEFAULT_SD_PATH="$(pwd)"
# ===========================================

PART_DEV="${DISK}p${PART_NUM}"

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
   echo "Error: Must run as root."
   exit 1
fi

echo "=== Part 0: Check environment and clean up ==="
# 确认一定要备份的是 eMMC，而当前启动的是 TF 卡
# 简单的检查：如果根目录 / 挂载的是 mmcblk0 (eMMC)，说明启动盘搞错了
ROOT_DEVICE=$(findmnt / -o SOURCE -n)
if [[ "$ROOT_DEVICE" == *"${DISK##*/}"* ]]; then
    echo "CRITICAL ERROR: System is booted from eMMC ($DISK)!"
    echo "You cannot backup the system drive while running on it using this method."
    echo "Please boot from TF Card first."
    exit 1
fi

# 注意：如果原本没有挂载，这里mount可能会报错，稍微改得健壮一点
if ! mountpoint -q /mnt/emmc_root; then
    mkdir -p /mnt/emmc_root
    mount $PART_DEV /mnt/emmc_root || true
fi

# 只有挂载成功才清理
if mountpoint -q /mnt/emmc_root; then
    echo "Cleaning logs and caches..."
    rm -rf /mnt/emmc_root/var/cache/apt/archives/*.deb
    rm -rf /mnt/emmc_root/var/log/*.log
    rm -rf /mnt/emmc_root/var/log/journal/*
    rm -rf /mnt/emmc_root/etc/NetworkManager/system-connections/*
    rm -rf /mnt/emmc_root/etc/machine-id

    umount /mnt/emmc_root
fi

# 尝试卸载 eMMC 的分区 (以防万一系统自动挂载了它)
umount -f $PART_DEV 2>/dev/null || true
if lsblk -no MOUNTPOINT $PART_DEV | grep -q .; then
    echo "CRITICAL ERROR: Target $PART_DEV is still mounted! Stop."
    exit 1
fi

echo "=== Part 1: Check filesystem ==="
echo "Checking filesystem on eMMC..."
e2fsck -f -y $PART_DEV

echo "=== Part 2: Calculate min size ==="
FS_BLOCK_SIZE=$(dumpe2fs -h $PART_DEV 2>/dev/null | grep "Block size:" | awk '{print $3}')

# 获取最小可用 block 数量 -->中文下会出错
# MIN_BLOCKS=$(resize2fs -P $PART_DEV 2>/dev/null | awk -F': ' '{print $2}')

# 强行指定语言为 C，这样输出格式固定为 "Estimated minimum size of the filesystem: 12345" -->测试可行
# MIN_BLOCKS=$(LC_ALL=C resize2fs -P /dev/mmcblk0p2 2>/dev/null | awk -F': ' '{print $2}')

# grep -o '[0-9]*$' 表示：只输出行尾($)的连续数字([0-9]*) -->测试可行
MIN_BLOCKS=$(resize2fs -P $PART_DEV 2>/dev/null | grep -o '[0-9]*$')

if [[ -z "$FS_BLOCK_SIZE" || -z "$MIN_BLOCKS" ]]; then
    echo "Error: Failed to calculate size."
    exit 1
fi

echo "Block Size: $FS_BLOCK_SIZE"
echo "Min Blocks: $MIN_BLOCKS"

# 计算大小
DATA_BYTES=$(( MIN_BLOCKS * FS_BLOCK_SIZE ))
BUFFER_BYTES=$(( BUFFER_SIZE_MB * 1024 * 1024 ))
TOTAL_BYTES=$(( DATA_BYTES + BUFFER_BYTES ))
REQUIRED_SECTORS=$(( (TOTAL_BYTES + 511) / 512 ))
ALIGNMENT=2048
REQUIRED_SECTORS=$(( ((REQUIRED_SECTORS + ALIGNMENT - 1) / ALIGNMENT) * ALIGNMENT ))

echo "Target Sectors: $REQUIRED_SECTORS"

echo "=== Part 3: Shrink Filesystem ==="
TARGET_FS_BLOCKS=$(( TOTAL_BYTES / FS_BLOCK_SIZE ))
echo "Resizing filesystem..."
resize2fs -p $PART_DEV $TARGET_FS_BLOCKS

echo "=== Part 4: Calculate Partition End ==="
PART_NAME=$(basename $PART_DEV)
START_SECTOR=$(cat /sys/class/block/$PART_NAME/start)
END_SECTOR=$(( START_SECTOR + REQUIRED_SECTORS - 1 ))

echo "Start Sector: $START_SECTOR"
echo "New End Sector: $END_SECTOR"

echo "=== Part 5: Shrink Partition ==="
# 使用 yes 自动回答
yes Yes | parted ---pretend-input-tty $DISK unit s resizepart $PART_NUM $END_SECTOR
partprobe $DISK || true
sleep 2

echo "=== Part 6: Sync Filesystem ==="
resize2fs $PART_DEV

echo "=== Part 7: Select Storage for Backup ==="
# 计算镜像所需大小 (MB)
DD_COUNT_MB=$(( ($END_SECTOR / 2048) + 10 ))
echo "Required Space: $DD_COUNT_MB MB"

TARGET_DIR=""
FOUND_STORAGE=0

# 函数：检查目录剩余空间 (MB)
check_space() {
    local dir=$1
    # 获取可用空间 (MB) - 这里用 df -m 确保单位统一
    local avail=$(df -m "$dir" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -z "$avail" ]]; then echo 0; else echo $avail; fi
}

# --- 7.1 自动寻找 USB ---
if [ "$FOUND_STORAGE" -eq 0 ]; then
    echo "Scanning for available USB storage..."

    BASE_MNT_DIR="/tmp/usb_mounts"

    # 【新增逻辑】：安全检查
    # 检查 BASE_MNT_DIR 是否本身就是一个挂载点
    # 如果是，这很不正常（可能是残留），尝试卸载它，或者换一个目录
    if mountpoint -q "$BASE_MNT_DIR" 2>/dev/null || grep -q " $BASE_MNT_DIR " /proc/mounts; then
        echo "Warning: $BASE_MNT_DIR is already a mount point. Unmounting it for safety..."
        umount "$BASE_MNT_DIR"
        
        # 如果卸载失败（比如正忙），则给目录加个后缀，防止嵌套挂载
        if [ $? -ne 0 ]; then
            echo "Failed to unmount $BASE_MNT_DIR. Switching base directory."
            BASE_MNT_DIR="/tmp/usb_mounts_safe_$(date +%s)"
        fi
    fi

    mkdir -p "$BASE_MNT_DIR"

    # 遍历 sd* (USB) 和 nvme*
    for dev in $(ls /dev/sd* /dev/nvme* 2>/dev/null | grep -E "[0-9]$|p[0-9]$"); do
        echo "Found candidate device: $dev"
        
        # 1. 检查系统是否已挂载
        EXISTING_MOUNT_POINT=$(grep "^$dev " /proc/mounts | awk '{print $2}' | head -n 1)
        SELF_MOUNTED=0

        if [ -n "$EXISTING_MOUNT_POINT" ]; then
            echo "  -> Device is already mounted by system at: $EXISTING_MOUNT_POINT"
            MNT_POINT="$EXISTING_MOUNT_POINT"
        else
            # 2. 未挂载，挂载到我们的安全目录下的子目录
            # 注意这里要把 dev 的名字（如 sda1）拼接到路径里，避免冲突
            MNT_POINT="$BASE_MNT_DIR/$(basename $dev)"
            mkdir -p "$MNT_POINT"

            if mount "$dev" "$MNT_POINT" 2>/dev/null; then
                SELF_MOUNTED=1
                echo "  -> Mounted by script at $MNT_POINT"
            else
                echo "Failed to mount $dev"
                rmdir "$MNT_POINT" 2>/dev/null
                continue
            fi
        fi

               # 检查空间
        USB_AVAIL=$(check_space "$MNT_POINT")
        echo "  -> Available: ${USB_AVAIL} MB"

        if [ "$USB_AVAIL" -gt "$DD_COUNT_MB" ]; then
            echo "Found valid USB storage!"
            TARGET_DIR="$MNT_POINT"
            FOUND_STORAGE=1
            break
        else
            echo "Space insufficient..."
            
            # --- 关键修改：只有脚本自己挂载的才卸载 ---
            if [ "$SELF_MOUNTED" -eq 1 ]; then
                echo "Unmounting temporary mount..."
                umount "$MNT_POINT"
                rmdir "$MNT_POINT" 2>/dev/null
            else
                echo "Skipping unmount (mounted by system)."
            fi
        fi
        
    done
fi

# --- 7.2 检查当前目录 (TF卡) ---
# 因为是从 TF 卡启动并运行脚本，默认路径就是 TF 卡
if [ "$FOUND_STORAGE" -eq 0 ]; then
	SD_AVAIL=$(check_space "$DEFAULT_SD_PATH")
	echo "Checking Current Path ($DEFAULT_SD_PATH): Available ${SD_AVAIL} MB"
	
	if [ "$SD_AVAIL" -gt "$DD_COUNT_MB" ]; then
	    echo "TF Card (Current Path) has enough space."
	    TARGET_DIR="$DEFAULT_SD_PATH"
	    FOUND_STORAGE=1
	else
	    echo "TF Card space insufficient (Need $DD_COUNT_MB MB, have $SD_AVAIL MB)."
	fi
fi


# --- 7.3 最终判断 ---
if [ "$FOUND_STORAGE" -eq 0 ]; then
    echo "CRITICAL ERROR: No suitable storage found (TF Card full & No valid USB)!"
    exit 1
fi

FINAL_OUTPUT_PATH="${TARGET_DIR}/${IMG_NAME}"

echo "========================================"
echo "Target Storage: $TARGET_DIR"
echo "Output File:    $FINAL_OUTPUT_PATH"
echo "========================================"

echo "=== Part 8: Execute DD ==="
dd if=$DISK of="$FINAL_OUTPUT_PATH" bs=1M count=$DD_COUNT_MB status=progress conv=fsync

echo "========================================"
echo "SUCCESS! Backup Complete."
echo "Image saved to: $FINAL_OUTPUT_PATH"
echo "Size: $(du -sh $FINAL_OUTPUT_PATH | awk '{print $1}')"
echo "You can verify partition table with: fdisk -l $FINAL_OUTPUT_PATH"
echo "========================================"
