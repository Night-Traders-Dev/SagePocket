# kernel/kernel.sage - SageOS kernel entry, initialization, scheduler loop.
#
# The kernel runs a cooperative, priority-based round-robin scheduler on a
# virtual millisecond clock (kernel/timer.sage). kernel_run() advances the
# clock, wakes sleeping tasks, polls interrupts, and dispatches one task
# quantum per step; it returns after `steps` dispatches so tests and the
# pico demo both drive the same bounded loop.
#
# Public API used by tests and the boot layer:
#   kernel_init()      reset subsystems
#   kernel_tick()      advance the virtual clock by 1 ms
#   kernel_run(steps)  run `steps` scheduling steps
#   kernel_panic(msg)  report and stop
#   kernel_stats()     {clock, dispatches, tasks, ready}

import kernel.process as process
import kernel.scheduler as scheduler
import kernel.timer as timer
import kernel.memory as memory
import kernel.ipc as ipc
import kernel.interrupt as interrupt
import kernel.syscall as syscall

var _panic_message = nil

proc kernel_init():
    _panic_message = nil
    scheduler.sched_init()

# kernel_step(ms): advance clock by ms, wake sleeping tasks, poll IRQs.
proc kernel_step(ms):
    timer.timer_tick(ms)
    var now = timer.time_now()
    process.proc_wake_due(now)
    interrupt.int_poll(now)

# kernel_run(steps): run `steps` scheduler dispatches, advancing the clock
# by 1 ms per step. Returns when done (deterministic host/device behavior).
proc kernel_run(steps):
    var i = 0
    while i < steps:
        kernel_step(1)
        scheduler.sched_dispatch()
        i = i + 1

proc kernel_panic(msg):
    _panic_message = msg
    print "SAGEOS KERNEL PANIC: " + msg

proc kernel_panic_message():
    return _panic_message

# --- task-facing API (called from inside a task fn) ------------------------

proc task_sleep(ms):
    var cur = scheduler.sched_current()
    if cur != nil:
        cur["state"] = process.TASK_SLEEPING
        cur["wake_at"] = timer.time_now() + ms

proc task_exit():
    var cur = scheduler.sched_current()
    if cur != nil:
        cur["state"] = process.TASK_TERMINATED

proc kernel_stats():
    var s = scheduler.sched_stats()
    var t = timer.timer_stats()
    return {"clock": t["clock"], "dispatches": s["dispatches"],
            "tasks": s["tasks"], "ready": s["ready"],
            "panic": _panic_message}