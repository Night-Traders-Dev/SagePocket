# tests/unit/scheduler.sage - Phase 5 kernel: multiple cooperative tasks.
#
# Runs three tasks (different priorities) on the virtual clock and checks
# they all got CPU time, sleeping wakes at the right time, and IPC
# handoff works. Expected outputs:
#   scheduler ok count 5
#   scheduler ok count 3
#   scheduler ok sleep woke
#   scheduler ok ipc TOTAL
#   scheduler ok done

import kernel.process as process
import kernel.scheduler as scheduler
import kernel.timer as timer
import kernel.ipc as ipc
import kernel.kernel as kernel

var counter_a = 0
var counter_b = 0
var sleep_woken = 0
var ipc_total = 0

proc task_a():
    counter_a = counter_a + 1
    if counter_a >= 5:
        kernel.task_exit()

proc task_b():
    counter_b = counter_b + 1
    if counter_b >= 3:
        kernel.task_exit()

proc task_sleeper():
    sleep_woken = sleep_woken + 1
    kernel.task_sleep(10)
    sleep_woken = sleep_woken + 1
    kernel.task_exit()

var mbox = ipc.ipc_mailbox_create(4)

proc task_producer():
    ipc.ipc_send(mbox, 10)
    ipc.ipc_send(mbox, 20)
    ipc.ipc_send(mbox, 30)
    kernel.task_exit()

proc task_consumer():
    var m = ipc.ipc_recv(mbox)
    if m == nil:
        return
    ipc_total = ipc_total + m
    if ipc_total >= 60:
        kernel.task_exit()

kernel.kernel_init()
scheduler.sched_add(process.proc_create("producer", task_producer, 200))
scheduler.sched_add(process.proc_create("consumer", task_consumer, 150))
scheduler.sched_add(process.proc_create("sleeper", task_sleeper, 100))
scheduler.sched_add(process.proc_create("alpha", task_a, 50))
scheduler.sched_add(process.proc_create("beta", task_b, 40))

kernel.kernel_run(200)

if counter_a == 5:
    print "scheduler ok count 5"
else:
    print "scheduler FAIL count_a=" + str(counter_a)

if counter_b == 3:
    print "scheduler ok count 3"
else:
    print "scheduler FAIL count_b=" + str(counter_b)

if sleep_woken == 2:
    print "scheduler ok sleep woke"
else:
    print "scheduler FAIL sleep_woken=" + str(sleep_woken)

if ipc_total == 60:
    print "scheduler ok ipc TOTAL"
else:
    print "scheduler FAIL ipc_total=" + str(ipc_total)

print "scheduler ok done"