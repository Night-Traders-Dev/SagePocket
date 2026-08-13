# kernel/syscall.sage - System call table and dispatch for SageOS.
#
# The kernel-side syscall table maps numbers to handler procs. Apps running
# under SageVM later enter through the VM ABI (see docs/sagevm.md §5); this
# module is the kernel-side registry and dispatcher that SageVM will call.
#
# API:
#   syscall_register(nr, handler)     install a handler (nil clears)
#   syscall_call(nr, a, b, c)         dispatch, nil when unregistered

var _syscalls = []

proc _syscalls_grow(nr):
    while len(_syscalls) <= nr:
        push(_syscalls, nil)

proc syscall_register(nr, handler):
    _syscalls_grow(nr)
    _syscalls[nr] = handler

proc syscall_call(nr, a, b, c):
    if nr < 0 or nr >= len(_syscalls):
        return nil
    var h = _syscalls[nr]
    if h == nil:
        return nil
    return h(a, b, c)

proc syscall_count():
    var n = 0
    var i = 0
    while i < len(_syscalls):
        if _syscalls[i] != nil:
            n = n + 1
        i = i + 1
    return n