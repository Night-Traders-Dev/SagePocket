# shell/commands.sage - SageShell built-in commands.
#
# Every command has the signature cmd(ctx, args) where args are the
# tokens after the command name. Commands write output with sh_out()
# (accumulated in ctx["out"] and echoed through the io hook) and report
# failures with sh_err(). They return true to keep the shell looping and
# false to stop it (only "exit" does that).
#
# Systems commands (ps, mem, ...) go through the ctx["sys"] hook dict of
# procs; when the hook is missing the command reports "not available",
# so the same shell runs in the interpreter, on host stubs, and on the
# pico.

import sagefs.vfs as vfs
import sagefs.inode as inode

var SH_CMDS = "help ls cd pwd cat cp mv rm mkdir touch mount umount df ps kill mem cpu temp uptime apps install uninstall run stop clear reboot shutdown exit"

# sh_out(ctx, s): append to the output accumulator and echo it.
proc sh_out(ctx, s):
    ctx["out"] = ctx["out"] + s
    var w = ctx["io"]["write"]
    w(s)

proc sh_err(ctx, s):
    sh_out(ctx, "error: " + s + "\n")

proc sh_errno(ctx, s):
    sh_out(ctx, s + ": operation failed\n")

# sh_abs(ctx, p): resolve a (possibly relative) path against the cwd and
# collapse "." and "..".
proc sh_abs(ctx, p):
    if p == "":
        return ctx["cwd"]
    var abs = ""
    if p[0] == "/":
        abs = p
    else:
        abs = ctx["cwd"] + "/" + p
    var comps = []
    var cur = ""
    var i = 0
    while i < len(abs):
        var c = abs[i]
        if c == "/":
            if cur != "":
                push(comps, cur)
                cur = ""
        else:
            cur = cur + c
        i = i + 1
    if cur != "":
        push(comps, cur)
    var stack = []
    i = 0
    while i < len(comps):
        if comps[i] == ".":
            i = i + 1
            continue
        if comps[i] == "..":
            if len(stack) > 0:
                pop(stack)
            i = i + 1
            continue
        push(stack, comps[i])
        i = i + 1
    var out = "/"
    i = 0
    while i < len(stack):
        out = out + stack[i]
        if i < len(stack) - 1:
            out = out + "/"
        i = i + 1
    return out

# --- filesystem commands ----------------------------------------------------

proc cmd_help(ctx, args):
    sh_out(ctx, "commands: " + SH_CMDS + "\n")
    return true

proc cmd_pwd(ctx, args):
    sh_out(ctx, ctx["cwd"] + "\n")
    return true

proc cmd_ls(ctx, args):
    var p = ctx["cwd"]
    if len(args) > 0:
        p = sh_abs(ctx, args[0])
    var entries = vfs.vfs_list(p)
    if entries == nil:
        sh_errno(ctx, "ls")
        return true
    var i = 0
    while i < len(entries):
        var nm = entries[i]["name"]
        if inode.inode_is_dir(entries[i]):
            nm = nm + "/"
        sh_out(ctx, nm + "\n")
        i = i + 1
    return true

proc cmd_cd(ctx, args):
    var p = ctx["cwd"]
    if len(args) > 0:
        p = sh_abs(ctx, args[0])
    var st = vfs.vfs_stat(p)
    if st == nil or not inode.inode_is_dir(st):
        sh_err(ctx, "cd: not a directory: " + args[0])
        return true
    ctx["cwd"] = p
    return true

proc cmd_cat(ctx, args):
    if len(args) < 1:
        sh_err(ctx, "cat: missing operand")
        return true
    var data = vfs.vfs_read_bytes(sh_abs(ctx, args[0]))
    if data == nil:
        sh_errno(ctx, "cat")
        return true
    sh_out(ctx, vfs.vfs_bytes_to_str(data) + "\n")
    return true

proc cmd_cp(ctx, args):
    if len(args) < 2:
        sh_err(ctx, "cp: missing operand")
        return true
    var data = vfs.vfs_read_bytes(sh_abs(ctx, args[0]))
    if data == nil:
        sh_errno(ctx, "cp")
        return true
    if not vfs.vfs_write_bytes(sh_abs(ctx, args[1]), data):
        sh_errno(ctx, "cp")
    return true

proc cmd_mv(ctx, args):
    if len(args) < 2:
        sh_err(ctx, "mv: missing operand")
        return true
    var src = sh_abs(ctx, args[0])
    var dst = sh_abs(ctx, args[1])
    var data = vfs.vfs_read_bytes(src)
    if data == nil:
        sh_errno(ctx, "mv")
        return true
    if not vfs.vfs_write_bytes(dst, data):
        sh_errno(ctx, "mv")
        return true
    if not vfs.vfs_remove(src):
        sh_err(ctx, "mv: remove source failed")
    return true

proc cmd_rm(ctx, args):
    if len(args) < 1:
        sh_err(ctx, "rm: missing operand")
        return true
    var i = 0
    while i < len(args):
        if not vfs.vfs_remove(sh_abs(ctx, args[i])):
            sh_errno(ctx, "rm")
        i = i + 1
    return true

proc cmd_mkdir(ctx, args):
    if len(args) < 1:
        sh_err(ctx, "mkdir: missing operand")
        return true
    var i = 0
    while i < len(args):
        if not vfs.vfs_mkdir(sh_abs(ctx, args[i])):
            sh_errno(ctx, "mkdir")
        i = i + 1
    return true

proc cmd_touch(ctx, args):
    if len(args) < 1:
        sh_err(ctx, "touch: missing operand")
        return true
    var i = 0
    while i < len(args):
        if not vfs.vfs_write_bytes(sh_abs(ctx, args[i]), []):
            sh_errno(ctx, "touch")
        i = i + 1
    return true

proc cmd_mount(ctx, args):
    var mounts = vfs.vfs_mount_info()
    var i = 0
    while i < len(mounts):
        var m = mounts[i]
        sh_out(ctx, m["point"] + " -> " + m["fsname"] + "\n")
        i = i + 1
    return true

proc cmd_umount(ctx, args):
    if len(args) < 1:
        sh_err(ctx, "umount: missing operand")
        return true
    if vfs.vfs_unmount(sh_abs(ctx, args[0])):
        sh_out(ctx, "unmounted " + args[0] + "\n")
    else:
        sh_errno(ctx, "umount")
    return true

proc cmd_df(ctx, args):
    var mounts = vfs.vfs_mount_info()
    var i = 0
    while i < len(mounts):
        var m = mounts[i]
        sh_out(ctx, m["point"] + "  " + m["fsname"] + "\n")
        i = i + 1
    return true

# --- system commands (through the sys hook) ---------------------------------

# sh_sys(ctx, key, args, fallback): call a sys hook proc, or report
# unavailability.
proc sh_sys(ctx, key, args, fallback):
    var sys = ctx["sys"]
    if sys == nil or sys[key] == nil:
        sh_out(ctx, fallback + "\n")
        return true
    var f = sys[key]
    var r = f(ctx, args)
    sh_out(ctx, r + "\n")
    return true

proc cmd_ps(ctx, args):
    return sh_sys(ctx, "ps", args, "ps: not available")

proc cmd_kill(ctx, args):
    return sh_sys(ctx, "kill", args, "kill: not available")

proc cmd_mem(ctx, args):
    return sh_sys(ctx, "mem", args, "mem: not available")

proc cmd_cpu(ctx, args):
    return sh_sys(ctx, "cpu", args, "cpu: not available")

proc cmd_temp(ctx, args):
    return sh_sys(ctx, "temp", args, "temp: not available")

proc cmd_uptime(ctx, args):
    return sh_sys(ctx, "uptime", args, "uptime: not available")

proc cmd_apps(ctx, args):
    return sh_sys(ctx, "apps", args, "apps: none")

proc cmd_install(ctx, args):
    return sh_sys(ctx, "install", args, "install: not available")

proc cmd_uninstall(ctx, args):
    return sh_sys(ctx, "uninstall", args, "uninstall: not available")

proc cmd_run(ctx, args):
    return sh_sys(ctx, "run", args, "run: not available")

proc cmd_stop(ctx, args):
    return sh_sys(ctx, "stop", args, "stop: not available")

proc cmd_reboot(ctx, args):
    return sh_sys(ctx, "reboot", args, "reboot: not available")

proc cmd_shutdown(ctx, args):
    return sh_sys(ctx, "shutdown", args, "shutdown: not available")

# --- console ----------------------------------------------------------------

proc cmd_clear(ctx, args):
    var c = ctx["io"]["clear"]
    if c != nil:
        c()
    return true

proc cmd_exit(ctx, args):
    ctx["exit"] = true
    return false

# --- registry ---------------------------------------------------------------

# shell_lookup(name): the command proc, or nil.
proc shell_lookup(name):
    if name == "help":
        return cmd_help
    if name == "ls":
        return cmd_ls
    if name == "cd":
        return cmd_cd
    if name == "pwd":
        return cmd_pwd
    if name == "cat":
        return cmd_cat
    if name == "cp":
        return cmd_cp
    if name == "mv":
        return cmd_mv
    if name == "rm":
        return cmd_rm
    if name == "mkdir":
        return cmd_mkdir
    if name == "touch":
        return cmd_touch
    if name == "mount":
        return cmd_mount
    if name == "umount":
        return cmd_umount
    if name == "df":
        return cmd_df
    if name == "ps":
        return cmd_ps
    if name == "kill":
        return cmd_kill
    if name == "mem":
        return cmd_mem
    if name == "cpu":
        return cmd_cpu
    if name == "temp":
        return cmd_temp
    if name == "uptime":
        return cmd_uptime
    if name == "apps":
        return cmd_apps
    if name == "install":
        return cmd_install
    if name == "uninstall":
        return cmd_uninstall
    if name == "run":
        return cmd_run
    if name == "stop":
        return cmd_stop
    if name == "clear":
        return cmd_clear
    if name == "reboot":
        return cmd_reboot
    if name == "shutdown":
        return cmd_shutdown
    if name == "exit":
        return cmd_exit
    return nil