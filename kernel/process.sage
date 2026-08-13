# kernel/process.sage - Task/process management for SageOS.
#
# A task is a Sage proc that the scheduler runs as a quantum. Tasks use
# the cooperative API (proc_yield, proc_sleep, ipc_recv) which operate on
# the currently running task via kernel.sage's _current pointer. A task
# that blocks is simply not scheduled until its condition clears; the
# kernel never runs task procs to completion in a single step.
#
# TCB fields:
#   id, name, fn (proc), state, priority (0..255, higher = first),
#   wake_at (ms, SLEEPING), block_src (BLOCKED mailbox), runs (count)

var TASK_READY = 0
var TASK_RUNNING = 1
var TASK_BLOCKED = 2
var TASK_SLEEPING = 3
var TASK_TERMINATED = 4

var _tasks = []
var _next_tid = 1

proc proc_create(name, fn, priority):
    var tcb = {}
    tcb["id"] = _next_tid
    _next_tid = _next_tid + 1
    tcb["name"] = name
    tcb["fn"] = fn
    tcb["state"] = TASK_READY
    tcb["priority"] = priority
    tcb["wake_at"] = 0
    tcb["block_src"] = nil
    tcb["runs"] = 0
    push(_tasks, tcb)
    return tcb

proc proc_find(tid):
    var i = 0
    while i < len(_tasks):
        if _tasks[i]["id"] == tid:
            return _tasks[i]
        i = i + 1
    return nil

proc proc_task_count():
    var n = 0
    var i = 0
    while i < len(_tasks):
        if _tasks[i]["state"] != TASK_TERMINATED:
            n = n + 1
        i = i + 1
    return n

proc proc_exit(tid):
    var t = proc_find(tid)
    if t != nil:
        t["state"] = TASK_TERMINATED

proc proc_set_state(tid, state):
    var t = proc_find(tid)
    if t != nil:
        t["state"] = state

proc proc_wake(tid):
    var t = proc_find(tid)
    if t != nil:
        t["state"] = TASK_READY

# proc_wake_due(now): wake every SLEEPING task whose wake_at has passed.
proc proc_wake_due(now):
    var i = 0
    while i < len(_tasks):
        var t = _tasks[i]
        if t["state"] == TASK_SLEEPING and t["wake_at"] <= now:
            t["state"] = TASK_READY
        i = i + 1

proc proc_stats():
    return {"total": len(_tasks), "alive": proc_task_count()}