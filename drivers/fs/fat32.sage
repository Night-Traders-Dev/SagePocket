# drivers/fs/fat32.sage - FAT32 filesystem (read + basic write).
#
# Reads and writes go through a block-device indirection: by default the
# SD card driver (drivers/sd/sd_spi.sage), but any device exposing the
# standard block-device interface (bd_read/bd_write) can be substituted
# with fat_set_blockdev() - e.g. a RAM disk for host-side tests.
#
# FAT32 layout used here:
#   - sector 0 is an MBR (partition LBA from entry 1) or a superfloppy BPB
#   - BPB: bytes/sector=512 fixed, sectors/cluster @13, reserved @14,
#     num fats @16, total32 @32, fatsz32 @36, root cluster @44
#   - data sectors start at reserved + num_fats * fatsz32
#   - cluster chain walk via the FAT; EOC = 0x0FFFFFF8..0x0FFFFFFF
#   - directory entries: 32 bytes, 8.3 names, LFN entries skipped,
#     0x00 = end of directory, 0xE5 = deleted
#   - write: allocate free clusters (FAT scan), link chain, write back
#     both FAT copies, create a root directory entry

import drivers.sd.sd_spi as sd

var _mounted = false
var _bd = nil
var FAT_BS = 0
var FAT_SPC = 1
var FAT_RESV = 0
var FAT_NFATS = 1
var FAT_FATSZ = 0
var FAT_ROOTCL = 2
var FAT_DATALBA = 0
var FAT_FATLBA = 0
var FAT_TOTSECT = 0

# --- block device indirection ----------------------------------------------

# fat_set_blockdev(dev): route all block I/O through the given device
# (must expose bd_read(blockno) and bd_write(blockno, data)). Passing nil
# restores the default SD card backend.
proc fat_set_blockdev(dev):
    _bd = dev

proc fat_blockdev():
    return _bd

# fat_read_block(lba): one 512-byte sector via the active backend.
proc fat_read_block(lba):
    if _bd == nil:
        return sd.sd_read_block(lba)
    var rf = _bd["bd_read"]
    return rf(lba)

# fat_write_block(lba, data): one 512-byte sector via the active backend.
proc fat_write_block(lba, data):
    if _bd == nil:
        return sd.sd_write_block(lba, data)
    var wf = _bd["bd_write"]
    return wf(lba, data)

var FAT_ATTR_RO = 0x01
var FAT_ATTR_HIDDEN = 0x02
var FAT_ATTR_SYS = 0x04
var FAT_ATTR_VOLID = 0x08
var FAT_ATTR_DIR = 0x10
var FAT_ATTR_ARCH = 0x20
var FAT_ATTR_LFN = 0x0F

var FAT_EOC_MIN = 0x0FFFFFF8
var FAT_EOC = 0x0FFFFFFF

# --- byte helpers ---------------------------------------------------------

proc fat_u16(buf, off):
    return buf[off] | (buf[off + 1] << 8)

proc fat_u32(buf, off):
    return buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16) | (buf[off + 3] << 24)

proc fat_put_u16(buf, off, v):
    buf[off] = v & 0xFF
    buf[off + 1] = (v >> 8) & 0xFF

proc fat_put_u32(buf, off, v):
    buf[off] = v & 0xFF
    buf[off + 1] = (v >> 8) & 0xFF
    buf[off + 2] = (v >> 16) & 0xFF
    buf[off + 3] = (v >> 24) & 0xFF

proc fat_upper(c):
    if c >= 97 and c <= 122:
        return c - 32
    return c

# fat_upper_name(s): full string uppercased (FAT directory names are stored
# uppercased, so lookups must be case-insensitive).
proc fat_upper_name(s):
    var out = ""
    var i = 0
    while i < len(s):
        out = out + chr(fat_upper(ord(s[i])))
        i = i + 1
    return out

proc fat_mounted():
    return _mounted

# fat_mount(): locate the FAT32 partition and parse its BPB.
proc fat_mount():
    var s0 = fat_read_block(0)
    if s0 == nil:
        return false
    var pstart = 0
    if fat_u16(s0, 510) == 0x55AA:
        pstart = fat_u32(s0, 454)
    var bpb = fat_read_block(pstart)
    if bpb == nil:
        return false
    if fat_u16(bpb, 510) != 0x55AA:
        return false
    var bps = fat_u16(bpb, 11)
    var spc = bpb[13]
    var resv = fat_u16(bpb, 14)
    var nfats = bpb[16]
    var fatsz = fat_u32(bpb, 36)
    var rootcl = fat_u32(bpb, 44)
    var tot = fat_u32(bpb, 32)
    if bps != 512 or spc == 0 or resv == 0 or nfats == 0 or fatsz == 0 or rootcl < 2:
        return false
    var fst = chr(bpb[82]) + chr(bpb[83]) + chr(bpb[84]) + chr(bpb[85]) + chr(bpb[86]) + chr(bpb[87]) + chr(bpb[88]) + chr(bpb[89])
    if fst != "FAT32   ":
        return false
    FAT_BS = pstart
    FAT_SPC = spc
    FAT_RESV = resv
    FAT_NFATS = nfats
    FAT_FATSZ = fatsz
    FAT_ROOTCL = rootcl
    FAT_TOTSECT = tot
    FAT_FATLBA = pstart + resv
    FAT_DATALBA = FAT_FATLBA + nfats * fatsz
    _mounted = true
    return true

# --- cluster chain --------------------------------------------------------

proc fat_cluster_lba(cluster):
    return FAT_DATALBA + (cluster - 2) * FAT_SPC

# fat_next_cluster(cluster): FAT entry value; -1 on read error.
proc fat_next_cluster(cluster):
    var off = cluster * 4
    var sec = fat_read_block(FAT_FATLBA + off / 512)
    if sec == nil:
        return -1
    return fat_u32(sec, off % 512) & 0x0FFFFFFF

# fat_set_cluster(cluster, value): write a FAT entry to every FAT copy.
proc fat_set_cluster(cluster, value):
    var off = cluster * 4
    var rel = off / 512
    var sec = fat_read_block(FAT_FATLBA + rel)
    if sec == nil:
        return false
    var o = off % 512
    var v = (fat_u32(sec, o) & 0xF0000000) | (value & 0x0FFFFFFF)
    fat_put_u32(sec, o, v)
    var f = 0
    while f < FAT_NFATS:
        if not fat_write_block(FAT_FATLBA + f * FAT_FATSZ + rel, sec):
            return false
        f = f + 1
    return true

# fat_cluster_chain(start): full chain as an array of clusters, nil on
# error. Stops at the first EOC value.
proc fat_cluster_chain(start):
    var chain = [start]
    var c = start
    var guard = 0
    while guard < 65536:
        var n = fat_next_cluster(c)
        if n < 0:
            return nil
        if n >= FAT_EOC_MIN:
            break
        if n < 2:
            return nil
        push(chain, n)
        c = n
        guard = guard + 1
    return chain

# fat_read_cluster(cluster): concatenated bytes of one cluster, nil on error.
proc fat_read_cluster(cluster):
    var out = []
    var i = 0
    while i < FAT_SPC:
        var s = fat_read_block(fat_cluster_lba(cluster) + i)
        if s == nil:
            return nil
        var j = 0
        while j < 512:
            push(out, s[j])
            j = j + 1
        i = i + 1
    return out

# --- directory parsing ----------------------------------------------------

# fat_entry_name(buf, off): 8.3 name from a directory entry; "" for LFN
# entries or fully-padded names.
proc fat_entry_name(buf, off):
    if (buf[off + 11] & 0x0F) == FAT_ATTR_LFN:
        return ""
    var name = ""
    var i = 0
    while i < 8:
        var c = buf[off + i]
        if c == 0x20:
            break
        if c == 0x05:
            c = 0xE5
        name = name + chr(c)
        i = i + 1
    var ext = ""
    i = 8
    while i < 11:
        var c = buf[off + i]
        if c == 0x20:
            break
        ext = ext + chr(c)
        i = i + 1
    if name == "":
        return ""
    if ext != "":
        return name + "." + ext
    return name

# fat_list_dir(start): array of {name, attr, cluster, size} dictionaries.
proc fat_list_dir(start):
    var entries = []
    var chain = fat_cluster_chain(start)
    if chain == nil:
        return entries
    var ci = 0
    while ci < len(chain):
        var secs = fat_read_cluster(chain[ci])
        if secs == nil:
            break
        var off = 0
        while off + 32 <= len(secs):
            if secs[off] == 0x00:
                return entries
            var name = fat_entry_name(secs, off)
            if secs[off] == 0xE5:
                off = off + 32
                continue
            if name == "":
                off = off + 32
                continue
            var attr = secs[off + 11]
            var cl = fat_u16(secs, off + 26) | (fat_u16(secs, off + 20) << 16)
            var size = fat_u32(secs, off + 28)
            push(entries, {"name": name, "attr": attr, "cluster": cl, "size": size})
            off = off + 32
        ci = ci + 1
    return entries

proc fat_ls():
    if not _mounted:
        return []
    return fat_list_dir(FAT_ROOTCL)

proc fat_find_file(name):
    var entries = fat_ls()
    name = fat_upper_name(name)
    var i = 0
    while i < len(entries):
        if entries[i]["name"] == name and (entries[i]["attr"] & FAT_ATTR_DIR) == 0:
            return entries[i]
        i = i + 1
    return nil

proc fat_find_dir(name):
    var entries = fat_ls()
    name = fat_upper_name(name)

# fat_read_file(entry): file content as an array of bytes, nil on error.
proc fat_read_file(entry):
    var chain = fat_cluster_chain(entry["cluster"])
    if chain == nil:
        return nil
    var out = []
    var ci = 0
    while ci < len(chain):
        var secs = fat_read_cluster(chain[ci])
        if secs == nil:
            return nil
        var j = 0
        while j < len(secs):
            push(out, secs[j])
            j = j + 1
        ci = ci + 1
    if len(out) > entry["size"]:
        return slice(out, 0, entry["size"])
    return out

proc fat_bytes_to_str(bytes):
    var s = ""
    var i = 0
    while i < len(bytes):
        s = s + chr(bytes[i])
        i = i + 1
    return s

proc fat_str_to_bytes(s):
    var out = []
    var i = 0
    while i < len(s):
        push(out, ord(s[i]))
        i = i + 1
    return out

# --- write path -----------------------------------------------------------

# fat_find_free_cluster(): first cluster with FAT value 0, or 0 if none.
proc fat_find_free_cluster():
    var max_c = 2 + FAT_TOTSECT / FAT_SPC
    var c = 2
    while c < max_c:
        var v = fat_next_cluster(c)
        if v < 0:
            return 0
        if v == 0:
            return c
        c = c + 1
    return 0

# fat_write_dir_entry(name, cluster, size): create a root directory entry.
# Searches the root chain for a free slot (0x00 or 0xE5). Returns true if
# the entry was written. Root directory extension is not implemented.
proc fat_write_dir_entry(name, cluster, size):
    var base = ""
    var ext = ""
    var dot = -1
    var i = 0
    while i < len(name):
        if name[i] == ".":
            dot = i
        i = i + 1
    if dot >= 0:
        base = slice(name, 0, dot)
        ext = slice(name, dot + 1, len(name))
    else:
        base = name
    if len(base) > 8 or len(ext) > 3:
        return false
    var e = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    var bi = 0
    while bi < 8:
        e[bi] = 0x20
        bi = bi + 1
    bi = 0
    while bi < len(base):
        e[bi] = fat_upper(ord(base[bi]))
        bi = bi + 1
    var ei = 8
    while ei < 11:
        e[ei] = 0x20
        ei = ei + 1
    ei = 8
    while ei < 8 + len(ext):
        e[ei] = fat_upper(ord(ext[ei - 8]))
        ei = ei + 1
    e[11] = FAT_ATTR_ARCH
    fat_put_u16(e, 26, cluster & 0xFFFF)
    fat_put_u16(e, 20, (cluster >> 16) & 0xFFFF)
    fat_put_u32(e, 28, size)
    var chain = fat_cluster_chain(FAT_ROOTCL)
    if chain == nil:
        return false
    var ci = 0
    while ci < len(chain):
        var lba0 = fat_cluster_lba(chain[ci])
        var si = 0
        while si < FAT_SPC:
            var sec = fat_read_block(lba0 + si)
            if sec == nil:
                return false
            var off = 0
            while off <= 480:
                if sec[off] == 0x00 or sec[off] == 0xE5:
                    var j = 0
                    while j < 32:
                        sec[off + j] = e[j]
                        j = j + 1
                    if not fat_write_block(lba0 + si, sec):
                        return false
                    return true
                off = off + 32
            si = si + 1
        ci = ci + 1
    return false

# fat_write_file(name, data): create (or truncate) an 8.3-named file with
# the given byte content in the root directory. Returns true on success.
proc fat_write_file(name, data):
    if not _mounted:
        return false
    if len(data) == 0:
        return fat_write_dir_entry(name, 0, 0)
    var clusters = []
    var first = 0
    var prev = 0
    var off = 0
    while off < len(data):
        var c = fat_find_free_cluster()
        if c == 0:
            return false
        if not fat_set_cluster(c, FAT_EOC):
            return false
        if first == 0:
            first = c
        if prev != 0:
            if not fat_set_cluster(prev, c):
                return false
        var lba0 = fat_cluster_lba(c)
        var si = 0
        while si < FAT_SPC:
            var sec = []
            var j = 0
            while j < 512:
                if off < len(data):
                    push(sec, data[off])
                else:
                    push(sec, 0)
                off = off + 1
                j = j + 1
            if not fat_write_block(lba0 + si, sec):
                return false
            si = si + 1
        prev = c
    if prev != 0:
        if not fat_set_cluster(prev, FAT_EOC):
            return false
    return fat_write_dir_entry(name, first, len(data))