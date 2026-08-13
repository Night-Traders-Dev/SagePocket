# kernel/scheduler.sage - Priority-based round-robin scheduler for SageOS.
#
# Cooperative, quantum-driven dispatch. The scheduler keeps a current task
# (sched_current()); each call to sched_dispatch() runs the highest-
# priority READY task for one quantum (a single invocation of its fn).
# Tasks voluntarily yield by returning; they can also sleep on the virtual
# clock or block on a mailbox via the kernel API, which mark the task so
# the scheduler picks the next one.
#
# API:
#   sched_init()           reset the ready queue
#   sched_add(tcb)         enqueue a task
#   sched_dispatch()       run one quantum; true when a task ran
#   sched_ready_count()    number of runnable tasks
#   sched_current()        the running TCB (nil between dispatches)
#   sched_stats() -> dict  counters for tests/diagnostics

import kernel.process as process

var _ready = []
var _current = nil
var _dispatch_count = 0

proc sched_init():
    _ready = []
    _current = nil
    _dispatch_count = 0

proc sched_add(tcb):
    push(_ready, tcb)

proc _remove_task(tcb):
    var out = []
    var i = 0
    while i < len(_ready):
        if _ready[i]["id"] != tcb["id"]:
            push(out, _ready[i])
        i = i + 1
    _ready = out

# _pick_next(): highest priority among READY tasks; ties broken round-robin
# by rotation. Returns nil when nothing is runnable.
proc _pick_next():
    var best = nil
    var i = 0
    while i < len(_ready):
        var t = _ready[i]
        if t["state"] == process.TASK_READY:
            if best == nil:
                best = t
            elif t["priority"] > best["priority"]:
                best = t
        i = i + 1
    if best != nil:
        _remove_task(best)
        push(_ready, best)
    return best

proc sched_dispatch():
    var t = _pick_next()
    if t == nil:
        return false
    t["state"] = process.TASK_RUNNING
    _current = t
    _dispatch_count = _dispatch_count + 1
    t["runs"] = t["runs"] + 1
    var fn = t["fn"]
    fn()
    # Back to READY unless the task blocked/terminated itself during the
    # quantum via the kernel API.
    if t["state"] == process.TASK_RUNNING:
        t["state"] = process.TASK_READY
    _current = nil
    return true

proc sched_ready_count():
    var n = 0
    var i = 0
    while i < len(_ready):
        var t = _ready[i]
        if t["state"] == process.TASK_READY:
            n = n + 1
        i = i + 1
    return n

proc sched_current():
    return _current

proc sched_stats():
    return {"dispatches": _dispatch_count, "tasks": len(_ready),
            "ready": sched_ready_count()}