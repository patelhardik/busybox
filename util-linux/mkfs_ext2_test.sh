#!/bin/sh

run_test() { # params: mke2fs_invocation image_name
    >$2
    dd seek=$((kilobytes-1)) bs=1K count=1 </dev/zero of=$2 >/dev/null 2>&1 || exit 1
    $1 -F $2 $kilobytes >$2.raw_out 2>&1 || return 1
    cat $2.raw_out \
    | grep -v '^mke2fs [0-9]*\.[0-9]*\.[0-9]* ' \
    | grep -v '^Maximum filesystem' \
    | grep -v '^Writing inode tables' \
    | grep -v '^Writing superblocks and filesystem accounting information' \
    | grep -v '^This filesystem will be automatically checked every' \
    | grep -v '^180 days, whichever comes first' \
    | sed 's/inodes, [0-9]* blocks/inodes, N blocks/' \
    | sed 's/blocks* unused./blocks unused/' \
    | sed 's/block groups*/block groups/' \
    | sed 's/ *$//' \
    | sed 's/blocks (.*%) reserved/blocks reserved/' \
    | grep -v '^$' \
    >$2.out
}

test_mke2fs() {
    echo Testing $kilobytes

    run_test '/sbin/mke2fs' image_std || return 1
    run_test './busybox mke2fs' image_bb || return 1

    diff -ua image_bb.out image_std.out >image.out.diff || {
	cat image.out.diff
	return 1
    }

    e2fsck -f -n image_bb >/dev/null 2>&1 || {
	echo "e2fsck error on image_bb"
	e2fsck -f -n image_bb
	exit 1
    }
}

# Should start from kilobytes=60, but e2fsck complains on it:
# e2fsck 1.41.4 (27-Jan-2009)
# Pass 1: Checking inodes, blocks, and sizes
# Pass 2: Checking directory structure
# Pass 3: Checking directory connectivity
# Pass 4: Checking reference counts
# Pass 5: Checking group summary information
# Inode bitmap differences:  +(9--11)
# Free inodes count wrong for group #0 (5, counted=8).
# Directories count wrong for group #0 (2, counted=1).
# Free inodes count wrong (5, counted=8).
# image_bb: 11/16 files (0.0% non-contiguous), 9/60 blocks
kilobytes=68
while true; do
    test_mke2fs #|| exit 1
    : $((kilobytes++))
done
exit

# Specific sizes with known differences:
# -:bbox +:standard

# -6240 inodes, 24908 blocks
# +6240 inodes, 24577 blocks
# -4 block group
# +3 block group
# -1560 inodes per group
# +2080 inodes per group
kilobytes=24908 test_mke2fs

# -304 inodes, N blocks
# +152 inodes, N blocks
# -304 inodes per group
# +152 inodes per group
kilobytes=1218 test_mke2fs

# -14464 inodes, N blocks
# +14448 inodes, N blocks
# -8 block group
# +7 block group
# -1808 inodes per group
# +2064 inodes per group
kilobytes=57696 test_mke2fs

# -warning: 239 blocks unused.
# +warning: 242 blocks unused.
kilobytes=49395 test_mke2fs

## This size results in "warning: 75 blocks unused"
#kilobytes=98380 test_mke2fs

while true; do
    kilobytes=$(( (RANDOM*RANDOM) % 1000000 + 60))
    test_mke2fs || exit 1
done
