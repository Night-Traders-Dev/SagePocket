# shell/demo.sage - Phase 7 demo: SageShell over the SageFS RAM volumes.
#
# Feeds a canned command script through the shell loop with a RAM-backed
# FAT32 "/" and a memfs "/tmp", then verifies the accumulated transcript
# (prompts plus command output). Runs identically in the interpreter and
# as a pico image; the USB console replaces the script feeder later.
#
# expected scripted interactions:
#   pwd / mkdir / cd .. / touch / ls / cat (empty file) / cp / mv / rm /
#   ps / df / mount / help / unknown command / exit

import sagefs.block as block
import sagefs.cache as cache
import sagefs.mkfs as mkfs
import sagefs.vfs as vfs
import sagefs.memfs as memfs
import sagefs.fatfs as fatfs
import shell.shell as sh

var _script = ["pwd", "mkdir /docs", "cd /docs", "pwd", "touch letter.txt",
               "ls", "cd /", "cat /docs/letter.txt",
               "cp /docs/letter.txt /docs/copy.txt", "ls /docs",
               "mv /docs/copy.txt /docs/moved.txt", "ls /docs",
               "rm /docs/moved.txt", "ps", "df", "mount", "help",
               "bogus", "exit"]
var _si = 0
var _out = ""

proc demo_write(s):
    _out = _out + s
    print(s)

proc demo_read():
    if _si >= len(_script):
        return nil
    var line = _script[_si]
    _si = _si + 1
    return line

proc demo_clear():
    print("")

proc sys_ps(ctx, args):
    return "PID 1 demo - running"

proc sys_mem(ctx, args):
    return "heap 4096/32768 bytes used"

proc sys_uptime(ctx, args):
    return "uptime 100 ms"

# demo_find(hay, needle): true if needle occurs in hay.
proc demo_find(hay, needle):
    var i = 0
    while i + len(needle) <= len(hay):
        if slice(hay, i, i + len(needle)) == needle:
            return true
        i = i + 1
    return false

proc demo_main():
    block.block_ram_init(128)
    var disk = block.block_ram_device()
    var cached = cache.cache_wrap(disk, 8)
    if not mkfs.mkfs_fat32(cached):
        print "shell: mkfs FAILED"
        return
    if not vfs.vfs_mount("/", fatfs.ffs_ops(), cached):
        print "shell: mount / FAILED"
        return
    if not vfs.vfs_mount("/tmp", memfs.mem_ops(), nil):
        print "shell: mount /tmp FAILED"
        return

    var io = {"read": demo_read, "write": demo_write, "clear": demo_clear}
    var sys = {"ps": sys_ps, "mem": sys_mem, "uptime": sys_uptime}
    var ctx = sh.shell_ctx_new(io, sys)
    sh.shell_loop(ctx)

    var expected = "sage> "
    var prompts = 0
    var i = 0
    while i < len(_out) - 5:
        if slice(_out, i, i + 6) == expected:
            prompts = prompts + 1
        i = i + 1
    if prompts >= 10:
        print "shell: prompt ok"
    else:
        print "shell: prompt FAILED count=" + str(prompts)

    if demo_find(_out, "unknown command: bogus"):
        print "shell: unknown cmd handled"
    else:
        print "shell: unknown cmd FAILED"

    if demo_find(_out, "/docs") and demo_find(_out, "MOVED.TXT"):
        print "shell: cat/mv ok"
    else:
        print "shell: cat/mv FAILED"

    if demo_find(_out, "fat32") and demo_find(_out, "memfs"):
        print "shell: df ok"
    else:
        print "shell: df FAILED"

    print "shell: demo done"

demo_main()