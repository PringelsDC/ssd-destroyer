#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must be run as root"
    exit 1
fi

# Warning
cat <<'EOF'

███████╗███████╗██████╗  ██████╗ 
██╔════╝██╔════╝██╔══██╗██╔═══██╗
███████╗█████╗  ██║  ██║██║   ██║
╚════██║██╔══╝  ██║  ██║██║   ██║
███████║███████╗██████╔╝╚██████╔╝
╚══════╝╚══════╝╚═════╝  ╚═════╝ 

THIS WILL DESTROY YOUR SSD FAST!
EOF

# Get target
read -p "Enter device to destroy (e.g., /dev/nvme0n1): " target

# Verify
if [ ! -b "$target" ]; then
    echo "ERROR: $target is not a valid block device"
    exit 1
fi

# Final confirmation
echo -e "\n\033[1;31mTARGET: $target"
lsblk -o NAME,MODEL,SIZE,FSTYPE,MOUNTPOINT "$target"
echo -e "\nLAST WARNING: This will DESTROY $target\033[0m"
read -p "Type 'KILLITNOW' to confirm: " confirm
[ "$confirm" != "KILLITNOW" ] && exit

# Temp files
tmpdir=$(mktemp -d)
seq_file="$tmpdir/deathseq.dat"
rand_file="$tmpdir/deathrand.dat"

# Cleanup trap
cleanup() {
    echo "Cleaning up..."
    sync
    rm -f "$seq_file" "$rand_file"
    rmdir "$tmpdir"
    exit
}
trap cleanup EXIT INT TERM

# Main destruction
echo -e "\n\033[1;31mBEGINNING SSD DESTRUCTION\033[0m"
echo "Press Ctrl+C to stop (damage will already be done)"

iteration=1
while true; do
    echo -e "\n=== WRITE CYCLE $iteration ==="
    date
    
    # 1. Massive Sequential Writes 
    echo "[1/3] Sequential Write Bombing (1GB x4 parallel)"
    for i in {1..4}; do
        dd if=/dev/urandom of="$seq_file.$i" bs=1M count=1024 status=none &
    done
    wait
    sync
    
    # 2. Random Writes 
    echo "[2/3] Random Write Torture (4K random writes)"
    fio --name=randkill --filename="$rand_file" --ioengine=libaio --iodepth=32 \
        --rw=randwrite --bs=4k --direct=1 --size=2G --runtime=60 --numjobs=4 \
        --group_reporting --eta=never --output-format=terse >/dev/null
    
    # 3. Direct Device Overwrite 
    echo "[3/3] Raw Device Hammering"
    dd if=/dev/urandom of="$target" bs=1M count=1024 status=progress
    sync
    
    iteration=$((iteration+1))
done
