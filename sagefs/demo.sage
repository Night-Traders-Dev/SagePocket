# sagefs/demo.sage - Phase 6 demo: SageFS VFS over a FAT32 RAM disk plus a
# memfs /tmp mount. Runs identically in the interpreter, the host smoke
# harness, and on the pico (no hardware required).

import sagefs.block as block
import sagefs.cache as cache
import sagefs.mkfs as mkfs
import sagefs.vfs as vfs
import sagefs.memfs as memfs
import sagefs.fatfs as fatfs

# demo_fill(count): a repeated pattern payload for the multi-cluster write
# test (the FAT chain is several clusters long on any real volume).
proc demo_fill(count):
    var out = []
    var i = 0
    while i < count:
        push(out, 65 + (i % 26))
        i = i + 1
    return out

proc demo_main():
    # mount the VFS: "/" is FAT32 on the RAM disk, "/tmp" is memfs
    block.block_ram_init(64)
    var disk = block.block_ram_device()
    var cached = cache.cache_wrap(disk, 8)
    if not mkfs.mkfs_fat32(cached):
        print "sagefs: mkfs FAILED"
        return
    if not vfs.vfs_mount("/", fatfs.ffs_ops(), cached):
        print "sagefs: mount / FAILED"
        return
    if not vfs.vfs_mount("/tmp", memfs.mem_ops(), nil):
        print "sagefs: mount /tmp FAILED"
        return

    var mounts = vfs.vfs_mount_info()
    print "sagefs: mounted " + str(len(mounts)) + " volumes"

    # --- FAT32 backend: write, read back, list ----------------------------
    var hello = vfs.vfs_str_to_bytes("hello sagefs")
    if not vfs.vfs_write_bytes("/hello.txt", hello):
        print "sagefs: write hello FAILED"

    var got = vfs.vfs_read_bytes("/hello.txt")
    if got == nil or len(got) != len(hello):
        print "sagefs: read hello FAILED len=" + str(len(got))
    else:
        print "sagefs: hello read back: " + vfs.vfs_bytes_to_str(got)

    # multi-cluster file (1000 bytes -> several FAT clusters)
    var big = demo_fill(1000)
    if not vfs.vfs_write_bytes("/big.bin", big):
        print "sagefs: write big FAILED"
    var biggot = vfs.vfs_read_bytes("/big.bin")
    var bigok = false
    if biggot != nil and len(biggot) == 1000:
        if biggot[0] == big[0] and biggot[999] == big[999]:
            bigok = true
    if bigok:
        print "sagefs: big file read back 1000 bytes ok"
    else:
        print "sagefs: big file MISMATCH len=" + str(len(biggot))

    # directory listing through the VFS
    var listing = vfs.vfs_list("/")
    var names = ""
    var i = 0
    while i < len(listing):
        if i > 0:
            names = names + " "
        names = names + listing[i]["name"]
        i = i + 1
    print "sagefs: root contains: " + names

    # stat a file through the VFS
    var st = vfs.vfs_stat("/hello.txt")
    if st != nil:
        print "sagefs: stat hello size=" + str(st["size"])
    else:
        print "sagefs: stat hello FAILED"

    # --- memfs backend: directories, seek, remove --------------------------
    vfs.vfs_mkdir("/tmp/work")
    var scratch = vfs.vfs_str_to_bytes("scratch data")
    if not vfs.vfs_write_bytes("/tmp/work/scratch.txt", scratch):
        print "sagefs: memfs write FAILED"
    var sgot = vfs.vfs_read_bytes("/tmp/work/scratch.txt")
    if sgot != nil and vfs.vfs_bytes_to_str(sgot) == "scratch data":
        print "sagefs: memfs scratch ok"
    else:
        print "sagefs: memfs scratch FAILED"

    # seek + partial read through the fd layer
    var fd = vfs.vfs_open("/hello.txt", "r")
    var used_seek = false
    if fd >= 0:
        if vfs.vfs_seek(fd, 6):
            var part = vfs.vfs_read(fd, 5)
            if part != nil and vfs.vfs_bytes_to_str(part) == "sagef":
                used_seek = true
        vfs.vfs_close(fd)
    if used_seek:
        print "sagefs: fd seek ok"
    else:
        print "sagefs: fd seek FAILED"

    # a mount point shows up as a directory in its parent's listing
    var tmpl = vfs.vfs_list("/")
    var saw_tmp = false
    i = 0
    while i < len(tmpl):
        if tmpl[i]["name"] == "tmp":
            saw_tmp = true
        i = i + 1
    if saw_tmp:
        print "sagefs: mount point /tmp visible"
    else:
        print "sagefs: mount point /tmp MISSING"

    if not vfs.vfs_remove("/tmp/work/scratch.txt"):
        print "sagefs: remove FAILED"
    var gone = vfs.vfs_stat("/tmp/work/scratch.txt")
    if gone == nil:
        print "sagefs: remove ok"
    else:
        print "sagefs: remove still there"

    # --- cache stats --------------------------------------------------------
    var stats = cache.cache_stats()
    if stats["hits"] > 0 and stats["misses"] > 0:
        print "sagefs: cache hits=" + str(stats["hits"]) + " misses=" + str(stats["misses"])
    else:
        print "sagefs: cache stats FAILED hits=" + str(stats["hits"]) + " misses=" + str(stats["misses"])

    vfs.vfs_sync()
    print "sagefs: demo done"

demo_main()