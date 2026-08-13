# sagefs/mkfs.sage - build a minimal FAT32 volume in pure Sage.
#
# mkfs_fat32(dev) formats a RAM disk (or any writable block device) as a
# small FAT32 volume understood by drivers/fs/fat32.sage. Layout for a
# 64-block (32 KiB) disk:
#
#   block 0    MBR with one partition (type 0x0C, start LBA 1)
#   block 1    BPB: bps=512, spc=1, reserved=1, nfats=1, tot=64,
#              fatsz=2, root cluster 2, "FAT32   "
#   blocks 2-3 FAT (FAT[0]=0x0FFFFFF8, FAT[1]=0x0FFFFFFF,
#                   FAT[2]=0x0FFFFFFF = root is one cluster)
#   block 4    root cluster 2 (empty directory)
#
# This mirrors the on-card layout (MBR + BPB) so the same driver parses
# both. Only intended for development/scratch volumes.

import sagefs.block as block

var MKFS_SECTORS = 64
var MKFS_FATSZ = 2
var MKFS_FATLBA = 2
var MKFS_DATALBA = 4
var MKFS_ROOTCL = 2

var MKFS_ATTR_ARCH = 0x20

proc mkfs_put_u16(buf, off, v):
    buf[off] = v & 0xFF
    buf[off + 1] = (v >> 8) & 0xFF

proc mkfs_put_u32(buf, off, v):
    buf[off] = v & 0xFF
    buf[off + 1] = (v >> 8) & 0xFF
    buf[off + 2] = (v >> 16) & 0xFF
    buf[off + 3] = (v >> 24) & 0xFF

proc mkfs_set_sig(buf):
    mkfs_put_u16(buf, 510, 0x55AA)

# mkfs_mbr(): partition table block.
proc mkfs_mbr():
    var b = block.block_blank()
    mkfs_put_u16(b, 510, 0x55AA)
    b[446] = 0x00
    b[450] = 0x0C
    mkfs_put_u32(b, 454, 1)
    mkfs_put_u32(b, 458, MKFS_SECTORS - 1)
    return b

# mkfs_bpb(): boot parameter block.
proc mkfs_bpb():
    var b = block.block_blank()
    mkfs_put_u16(b, 11, 512)
    b[13] = 1
    mkfs_put_u16(b, 14, 1)
    b[16] = 1
    mkfs_put_u32(b, 32, MKFS_SECTORS)
    mkfs_put_u32(b, 36, MKFS_FATSZ)
    mkfs_put_u32(b, 44, MKFS_ROOTCL)
    var fsname = "FAT32   "
    var i = 0
    while i < 8:
        b[82 + i] = ord(fsname[i])
        i = i + 1
    mkfs_set_sig(b)
    return b

# mkfs_fat(): FAT with root cluster marked as end-of-chain.
proc mkfs_fat():
    var b = block.block_blank()
    mkfs_put_u32(b, 0, 0x0FFFFFF8)
    mkfs_put_u32(b, 4, 0x0FFFFFFF)
    mkfs_put_u32(b, 8, 0x0FFFFFFF)
    return b

# mkfs_fat32(dev): format the device. Returns true on success.
proc mkfs_fat32(dev):
    var nf = dev["bd_blocks"]
    if nf() < MKFS_SECTORS:
        return false
    var wf = dev["bd_write"]
    var mbr = mkfs_mbr()
    var bpb = mkfs_bpb()
    var fat = mkfs_fat()
    var root = block.block_blank()
    if not wf(0, mbr):
        return false
    if not wf(1, bpb):
        return false
    var f = 0
    while f < MKFS_FATSZ:
        if not wf(MKFS_FATLBA + f, fat):
            return false
        f = f + 1
    if not wf(MKFS_DATALBA, root):
        return false
    return true