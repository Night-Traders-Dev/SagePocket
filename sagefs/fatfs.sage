# sagefs/fatfs.sage - FAT32 backend for the SageFS VFS.
#
# Implements the backend ops over drivers/fs/fat32.sage, including nested
# subdirectories: every op resolves the path through the FAT directory
# tree, so "/dir/file" works as well as "/file".
#
# Mounting routes the block device through fat_set_blockdev() (RAM disks
# for tests; the SD card remains the default backend when dev is nil).

import drivers.fs.fat32 as fat
import sagefs.inode as inode
import sagefs.vfs as vfs

# ffs_mount(dev): attach the FAT32 volume on the given block device (nil
# keeps the default SD backend). Returns fat_mount()'s result.
proc ffs_mount(dev):
    if dev != nil:
        fat.fat_set_blockdev(dev)
    return fat.fat_mount()

# ffs_stat(path): inode for a path, nil if unknown.
proc ffs_stat(path):
    if path == "/":
        return inode.inode_dir("/")
    var r = fat.fat_resolve_path(path)
    if r == nil:
        return nil
    if r["entry"] == nil:
        return nil
    return inode.inode_from_entry(r["entry"])

# ffs_list(path): entries of a directory (root or nested).
proc ffs_list(path):
    var dircl = fat.FAT_ROOTCL
    if path != "/":
        var r = fat.fat_resolve_path(path)
        if r == nil or r["entry"] == nil:
            return []
        var entry = r["entry"]
        if (entry["attr"] & fat.FAT_ATTR_DIR) == 0:
            return []
        dircl = entry["cluster"]
    var dir_entries = fat.fat_list_dir(dircl)
    var out = []
    var i = 0
    while i < len(dir_entries):
        push(out, inode.inode_from_entry(dir_entries[i]))
        i = i + 1
    return out

# ffs_open(path, mode): per-fd state. Mode "r" requires the file to exist;
# mode "w" creates or truncates it (written out on close).
proc ffs_open(path, mode):
    var r = fat.fat_resolve_path(path)
    if r == nil:
        return nil
    var name = r["name"]
    if mode == "r":
        if r["entry"] == nil:
            return nil
        return {"name": name, "dir": r["dir"], "entry": r["entry"],
                "mode": "r", "pos": 0, "data": nil, "buf": nil}
    return {"name": name, "dir": r["dir"], "entry": nil, "mode": "w",
            "pos": 0, "data": nil, "buf": []}

# ffs_read(state, n): up to n bytes from the fd position. The whole file is
# read once and cached in the fd state.
proc ffs_read(state, n):
    if state["data"] == nil:
        var whole = fat.fat_read_file(state["entry"])
        if whole == nil:
            return nil
        state["data"] = whole
    var data = state["data"]
    var pos = state["pos"]
    if pos >= len(data) or n <= 0:
        return []
    var eend = pos + n
    if eend > len(data):
        eend = len(data)
    var out = []
    var i = pos
    while i < eend:
        push(out, data[i])
        i = i + 1
    state["pos"] = eend
    return out

# ffs_write(state, data): accumulate into the pending buffer.
proc ffs_write(state, data):
    var i = 0
    while i < len(data):
        push(state["buf"], data[i])
        i = i + 1
    return true

# ffs_seek(state, off): absolute position (buffered reads only).
proc ffs_seek(state, off):
    if off < 0:
        return false
    state["pos"] = off
    return true

# ffs_close(state): flush a written buffer to the FAT volume.
proc ffs_close(state):
    if state["mode"] == "w" and state["buf"] != nil:
        return fat.fat_write_file_in(state["dir"], state["name"],
                                     state["buf"])
    return true

# ffs_mkdir(path): make a directory (parent must exist).
proc ffs_mkdir(path):
    var r = fat.fat_resolve_path(path)
    if r == nil or r["name"] == "":
        return false
    return fat.fat_mkdir_in(r["dir"], r["name"])

# ffs_remove(path): delete a file or an empty directory.
proc ffs_remove(path):
    var r = fat.fat_resolve_path(path)
    if r == nil or r["entry"] == nil:
        return false
    if (r["entry"]["attr"] & fat.FAT_ATTR_DIR) != 0:
        return fat.fat_rmdir_in(r["dir"], r["name"])
    return fat.fat_remove_entry(r["dir"], r["name"])

# ffs_sync(): writes are flushed on close; nothing else pending.
proc ffs_sync():
    return true

# ffs_ops(): the backend ops dict for vfs.vfs_mount().
proc ffs_ops():
    return {"op_name": "fat32", "op_mount": ffs_mount,
            "op_open": ffs_open, "op_read": ffs_read,
            "op_write": ffs_write, "op_seek": ffs_seek,
            "op_close": ffs_close, "op_stat": ffs_stat,
            "op_list": ffs_list, "op_mkdir": ffs_mkdir,
            "op_remove": ffs_remove, "op_sync": ffs_sync}