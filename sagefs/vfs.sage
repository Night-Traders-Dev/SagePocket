# sagefs/vfs.sage - the SageFS virtual filesystem.
#
# A single namespace over mounted filesystems. Each mount is
#
#   {"point": canonical mount path, "fs": backend ops dict}
#
# A backend ops dict provides op_name and any of: op_mount, op_open,
# op_read, op_write, op_seek, op_close, op_stat, op_list, op_mkdir,
# op_remove, op_sync. Missing ops degrade gracefully (nil/false).
#
# File descriptors are small integers; each fd carries its backend ops
# dict plus per-fd state that the backend maintains (position, buffers).
#
# Paths are absolute, normalized, and resolve to the mount whose point is
# the longest prefix (so "/tmp/x" hits the /tmp mount, not "/").

import sagefs.inode as inode

var _mounts = []
var _fds = []

# --- path helpers ----------------------------------------------------------

# vfs_norm(path): canonical form - starts with "/", no duplicate slashes,
# no trailing slash except the root itself.
proc vfs_norm(path):
    var out = "/"
    var i = 0
    while i < len(path):
        var ch = path[i]
        if ch == "/":
            if out[len(out) - 1] != "/":
                out = out + "/"
        else:
            out = out + ch
        i = i + 1
    while len(out) > 1 and out[len(out) - 1] == "/":
        out = slice(out, 0, len(out) - 1)
    return out

# vfs_basename(path): last component ("/a/b" -> "b", "/" -> "").
proc vfs_basename(path):
    var p = vfs_norm(path)
    var i = len(p) - 1
    while i >= 0:
        if p[i] == "/":
            return slice(p, i + 1, len(p))
        i = i - 1
    return p

# vfs_dirname(path): parent directory ("/a/b" -> "/a", "/b" -> "/").
proc vfs_dirname(path):
    var p = vfs_norm(path)
    var i = len(p) - 1
    while i >= 0:
        if p[i] == "/":
            if i == 0:
                return "/"
            return slice(p, 0, i)
        i = i - 1
    return "/"

# --- mounts ----------------------------------------------------------------

# vfs_mount(point, ops, dev): attach a backend at point. Calls op_mount(dev)
# if the backend provides it. Returns false if the backend refuses.
proc vfs_mount(point, ops, dev):
    var p = vfs_norm(point)
    if ops["op_name"] == nil:
        return false
    var i = 0
    while i < len(_mounts):
        if _mounts[i]["point"] == p:
            return false
        i = i + 1
    push(_mounts, {"point": p, "fs": ops})
    if ops["op_mount"] != nil:
        if not ops["op_mount"](dev):
            var j = 0
            var kept = []
            while j < len(_mounts):
                if _mounts[j]["point"] != p:
                    push(kept, _mounts[j])
                j = j + 1
            _mounts = kept
            return false
    return true

# vfs_unmount(point): detach; true if it was mounted.
proc vfs_unmount(point):
    var p = vfs_norm(point)
    var i = 0
    var kept = []
    var found = false
    while i < len(_mounts):
        if _mounts[i]["point"] == p:
            found = true
        else:
            push(kept, _mounts[i])
        i = i + 1
    _mounts = kept
    return found

# vfs_mount_info(): array of {"point", "fsname"} for diagnostics.
proc vfs_mount_info():
    var out = []
    var i = 0
    while i < len(_mounts):
        var m = _mounts[i]
        push(out, {"point": m["point"], "fsname": m["fs"]["op_name"]})
        i = i + 1
    return out

# vfs_resolve(path): longest-point match -> {"fs": ops, "sub": rel path}.
# Returns {"fs": nil} when nothing is mounted.
proc vfs_resolve(path):
    var p = vfs_norm(path)
    if len(_mounts) == 0:
        return {"fs": nil, "sub": p, "point": ""}
    var best = nil
    var bestlen = -1
    var i = 0
    while i < len(_mounts):
        var pt = _mounts[i]["point"]
        if p == pt:
            if len(pt) > bestlen:
                best = _mounts[i]
                bestlen = len(pt)
        else:
            if pt != "/" and len(p) > len(pt):
                if p[len(pt)] == "/" and slice(p, 0, len(pt)) == pt:
                    if len(pt) > bestlen:
                        best = _mounts[i]
                        bestlen = len(pt)
        i = i + 1
    if best == nil:
        if len(_mounts) == 0:
            return {"fs": nil, "sub": p, "point": ""}
        return {"fs": _mounts[0]["fs"], "sub": p, "point": "/"}
    return {"fs": best["fs"], "sub": slice(p, bestlen, len(p)), "point": best["point"]}

# --- namespace operations ----------------------------------------------------

# vfs_stat(path): inode dict or nil.
proc vfs_stat(path):
    var r = vfs_resolve(path)
    if r["fs"] == nil:
        return nil
    if r["fs"]["op_stat"] == nil:
        return nil
    var sub = r["sub"]
    if sub == "":
        sub = "/"
    return r["fs"]["op_stat"](sub)

# vfs_list(path): array of inode dicts, including mount points nested in
# the directory.
proc vfs_list(path):
    var p = vfs_norm(path)
    var r = vfs_resolve(p)
    var out = []
    if r["fs"] == nil:
        return out
    if r["fs"]["op_list"] != nil:
        var sub = r["sub"]
        if sub == "":
            sub = "/"
        var entries = r["fs"]["op_list"](sub)
        var i = 0
        while i < len(entries):
            push(out, entries[i])
            i = i + 1
    var j = 0
    while j < len(_mounts):
        var pt = _mounts[j]["point"]
        if pt == "/":
            j = j + 1
            continue
        if vfs_dirname(pt) == p:
            push(out, inode.inode_dir(vfs_basename(pt)))
        j = j + 1
    return out

# vfs_mkdir(path): create a directory. Returns false on failure.
proc vfs_mkdir(path):
    var r = vfs_resolve(path)
    if r["fs"] == nil:
        return false
    if r["fs"]["op_mkdir"] == nil:
        return false
    var sub = r["sub"]
    if sub == "":
        return false
    return r["fs"]["op_mkdir"](sub)

# vfs_remove(path): delete a file or empty directory.
proc vfs_remove(path):
    var r = vfs_resolve(path)
    if r["fs"] == nil:
        return false
    if r["fs"]["op_remove"] == nil:
        return false
    var sub = r["sub"]
    if sub == "":
        return false
    return r["fs"]["op_remove"](sub)

# vfs_sync(): flush every mounted backend.
proc vfs_sync():
    var i = 0
    var ok = true
    while i < len(_mounts):
        if _mounts[i]["fs"]["op_sync"] != nil:
            if not _mounts[i]["fs"]["op_sync"]():
                ok = false
        i = i + 1
    return ok

# --- file descriptors --------------------------------------------------------

# vfs_open(path, mode): returns a non-negative fd or -1.
proc vfs_open(path, mode):
    var r = vfs_resolve(path)
    if r["fs"] == nil:
        return -1
    if r["fs"]["op_open"] == nil:
        return -1
    var sub = r["sub"]
    if sub == "":
        return -1
    var impl = r["fs"]["op_open"](sub, mode)
    if impl == nil:
        return -1
    var fd = 0
    while fd < len(_fds):
        if _fds[fd] == nil:
            _fds[fd] = {"fs": r["fs"], "impl": impl, "mode": mode}
            return fd + 1
        fd = fd + 1
    push(_fds, {"fs": r["fs"], "impl": impl, "mode": mode})
    return len(_fds)

# vfs_getfd(fd): fd state dict or nil.
proc vfs_getfd(fd):
    if fd < 1 or fd > len(_fds):
        return nil
    return _fds[fd - 1]

# vfs_close(fd): flush and release the descriptor.
proc vfs_close(fd):
    var st = vfs_getfd(fd)
    if st == nil:
        return false
    var ok = true
    if st["fs"]["op_close"] != nil:
        ok = st["fs"]["op_close"](st["impl"])
    _fds[fd - 1] = nil
    return ok

# vfs_read(fd, n): up to n bytes as an array, nil on error.
proc vfs_read(fd, n):
    var st = vfs_getfd(fd)
    if st == nil:
        return nil
    if st["fs"]["op_read"] == nil:
        return nil
    return st["fs"]["op_read"](st["impl"], n)

# vfs_read_all(fd): the full remaining content as one byte array.
proc vfs_read_all(fd):
    var out = []
    var chunk = 0
    var guard = 0
    while guard < 1024:
        chunk = vfs_read(fd, 256)
        if chunk == nil:
            return nil
        if len(chunk) == 0:
            return out
        var i = 0
        while i < len(chunk):
            push(out, chunk[i])
            i = i + 1
        guard = guard + 1
    return out

# vfs_write(fd, data): append bytes at the fd position.
proc vfs_write(fd, data):
    var st = vfs_getfd(fd)
    if st == nil:
        return false
    if st["fs"]["op_write"] == nil:
        return false
    return st["fs"]["op_write"](st["impl"], data)

# vfs_seek(fd, off): absolute position.
proc vfs_seek(fd, off):
    var st = vfs_getfd(fd)
    if st == nil:
        return false
    if st["fs"]["op_seek"] == nil:
        return false
    return st["fs"]["op_seek"](st["impl"], off)

# --- convenience --------------------------------------------------------------

# vfs_read_bytes(path): whole file content, or nil.
proc vfs_read_bytes(path):
    var fd = vfs_open(path, "r")
    if fd < 0:
        return nil
    var data = vfs_read_all(fd)
    vfs_close(fd)
    return data

# vfs_write_bytes(path, data): create/replace a file with byte content.
proc vfs_write_bytes(path, data):
    var fd = vfs_open(path, "w")
    if fd < 0:
        return false
    var ok = vfs_write(fd, data)
    if not vfs_close(fd):
        ok = false
    return ok

# vfs_bytes_to_str(bytes): byte array to a string.
proc vfs_bytes_to_str(bytes):
    var s = ""
    var i = 0
    while i < len(bytes):
        s = s + chr(bytes[i])
        i = i + 1
    return s

# vfs_str_to_bytes(s): string to a byte array.
proc vfs_str_to_bytes(s):
    var out = []
    var i = 0
    while i < len(s):
        push(out, ord(s[i]))
        i = i + 1
    return out