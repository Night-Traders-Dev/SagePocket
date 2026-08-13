# sagefs/memfs.sage - in-memory filesystem backend.
#
# A full-featured RAM filesystem used for VFS unit tests, host smoke
# coverage, and pico scratch space (/tmp). It implements the whole set of
# backend ops (open/read/write/seek/close/stat/list/mkdir/remove) so the
# VFS dispatch layer is exercised without any storage hardware.
#
# Layout: one treemap per directory:
#   {"kind": "file", "data": [bytes]}  or
#   {"kind": "dir",  "children": {name: entry...}, "names": [name...]}
# "names" tracks insertion order (compiled backends do not iterate dicts).

import sagefs.inode as inode

var _m_tree = {}

# mem_reset(): start with an empty root directory.
proc mem_reset():
    _m_tree = {"children": {}, "names": []}

# _m_dir_get(node, name): child or nil.
proc _m_dir_get(node, name):
    return node["children"][name]

# _m_dir_has(node, name): true if the child exists.
proc _m_dir_has(node, name):
    return node["children"][name] != nil

# _m_dir_add(node, name, entry): add a child entry.
proc _m_dir_add(node, name, entry):
    node["children"][name] = entry
    var i = 0
    var found = false
    while i < len(node["names"]):
        if node["names"][i] == name:
            found = true
        i = i + 1
    if not found:
        push(node["names"], name)

# _m_dir_del(node, name): remove a child entry.
proc _m_dir_del(node, name):
    node["children"][name] = nil
    var i = 0
    var kept = []
    while i < len(node["names"]):
        if node["names"][i] != name:
            push(kept, node["names"][i])
        i = i + 1
    node["names"] = kept

# _m_dir_names(node): array of child names.
proc _m_dir_names(node):
    return node["names"]

# _m_parts(path): split "/a/b/c" into individual components.
proc _m_parts(path):
    var out = []
    var cur = ""
    var i = 0
    while i < len(path):
        var ch = path[i]
        if ch == "/":
            if cur != "":
                push(out, cur)
                cur = ""
        else:
            cur = cur + ch
        i = i + 1
    if cur != "":
        push(out, cur)
    return out

# _m_walk(parts, create): descend to the dict holding the last component.
# With create=true, missing intermediate directories are created. Returns
# nil on error (missing path and not creating, or parent is a file).
proc _m_walk(parts, create):
    var node = _m_tree
    var i = 0
    while i < len(parts) - 1:
        var name = parts[i]
        if not _m_dir_has(node, name):
            if not create:
                return nil
            _m_dir_add(node, name, {"kind": "dir", "children": {}, "names": []})
        var child = _m_dir_get(node, name)
        if child["kind"] != "dir":
            return nil
        node = child
        i = i + 1
    return node

# mem_stat(path): inode for the path, or nil.
proc mem_stat(path):
    var parts = _m_parts(path)
    if len(parts) == 0:
        return inode.inode_dir("/")
    var node = _m_walk(parts, false)
    if node == nil:
        return nil
    var name = parts[len(parts) - 1]
    var entry = _m_dir_get(node, name)
    if entry == nil:
        return nil
    if entry["kind"] == "dir":
        return inode.inode_dir(name)
    return inode.inode_file(name, len(entry["data"]), 0)

# mem_list(path): array of inode dicts for the directory contents.
proc mem_list(path):
    var parts = _m_parts(path)
    var node = _m_tree
    if len(parts) > 0:
        node = _m_walk(parts, false)
    if node == nil:
        return []
    var names = _m_dir_names(node)
    var out = []
    var i = 0
    while i < len(names):
        var name = names[i]
        var entry = _m_dir_get(node, name)
        if entry["kind"] == "dir":
            push(out, inode.inode_dir(name))
        else:
            push(out, inode.inode_file(name, len(entry["data"]), 0))
        i = i + 1
    return out

# mem_mkdir(path): create a directory (including parents). Returns false
# if the leaf already exists.
proc mem_mkdir(path):
    var parts = _m_parts(path)
    if len(parts) == 0:
        return false
    var node = _m_walk(parts, true)
    if node == nil:
        return false
    var name = parts[len(parts) - 1]
    if _m_dir_has(node, name):
        return false
    _m_dir_add(node, name, {"kind": "dir", "children": {}, "names": []})
    return true

# mem_remove(path): delete a file or an empty directory. Returns false on
# missing paths or non-empty directories.
proc mem_remove(path):
    var parts = _m_parts(path)
    if len(parts) == 0:
        return false
    var node = _m_walk(parts, false)
    if node == nil:
        return false
    var name = parts[len(parts) - 1]
    var entry = _m_dir_get(node, name)
    if entry == nil:
        return false
    if entry["kind"] == "dir" and len(entry["names"]) > 0:
        return false
    _m_dir_del(node, name)
    return true

# mem_open(path, mode): per-fd state dict. Creates the file for "w".
proc mem_open(path, mode):
    var parts = _m_parts(path)
    if len(parts) == 0:
        return nil
    var node = _m_walk(parts, mode == "w")
    if node == nil:
        return nil
    var name = parts[len(parts) - 1]
    var entry = _m_dir_get(node, name)
    if entry == nil:
        entry = {"kind": "file", "data": []}
        _m_dir_add(node, name, entry)
    if entry["kind"] != "file":
        return nil
    return {"entry": entry, "mode": mode, "pos": 0}

# mem_read(state, n): up to n bytes from the fd position.
proc mem_read(state, n):
    var data = state["entry"]["data"]
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

# mem_write(state, data): append/replace bytes at the fd position.
proc mem_write(state, data):
    var entry = state["entry"]
    var pos = state["pos"]
    var i = 0
    while i < len(data):
        if pos < len(entry["data"]):
            entry["data"][pos] = data[i]
        else:
            push(entry["data"], data[i])
        pos = pos + 1
        i = i + 1
    state["pos"] = pos
    return true

# mem_seek(state, off): absolute position.
proc mem_seek(state, off):
    if off < 0:
        return false
    state["pos"] = off
    return true

# mem_sync(): nothing to flush in memory.
proc mem_sync():
    return true

# mem_close(state): nothing to flush.
proc mem_close(state):
    return true

# mem_mount(dev): ignore the device, start empty.
proc mem_mount(dev):
    mem_reset()
    return true

# mem_ops(): the backend ops dict for vfs.vfs_mount().
proc mem_ops():
    return {"op_name": "memfs", "op_mount": mem_mount,
            "op_open": mem_open, "op_read": mem_read,
            "op_write": mem_write, "op_seek": mem_seek,
            "op_close": mem_close, "op_stat": mem_stat,
            "op_list": mem_list, "op_mkdir": mem_mkdir,
            "op_remove": mem_remove, "op_sync": mem_sync}