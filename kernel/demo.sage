# kernel/demo.sage - SageOS kernel demo: three concurrent tasks.
#
# Runs the cooperative scheduler with a real hardware clock (hw.uptime_ms)
# on the RP2350: a priority task, a sleeping task, and a mailbox
# producer/consumer pair. Prints task progress over stdio every so often.
#
# Compile:  sage --compile-pico kernel/demo.sage -o build/demo \
#             --name sageos_demo --board waveshare_rp2350_lcd_1_47 \
#             --chip rp2350-arm --sdk .deps/pico-sdk --board-dir boards
# (then load the resulting UF2 like any demo; serial console shows output)

import hw
import kernel.process as process
import kernel.scheduler as scheduler
import kernel.timer as timer
import kernel.ipc as ipc
import kernel.kernel as kernel

var tick_a = 0
var tick_b = 0
var delivered = 0
var mbox = ipc.ipc_mailbox_create(4)

proc task_alpha():
    tick_a = tick_a + 1
    if tick_a % 25 == 0:
        print "alpha: tick " + str(tick_a)
    if tick_a >= 100:
        kernel.task_exit()

proc task_beta():
    tick_b = tick_b + 1
    kernel.task_sleep(30)
    if tick_b >= 20:
        kernel.task_exit()

var produced = 0

proc task_producer():
    produced = produced + 1
    ipc.ipc_send(mbox, 1)
    if produced >= 20:
        kernel.task_exit()

proc task_consumer():
    var m = ipc.ipc_recv(mbox)
    if m != nil:
        delivered = delivered + m
        if delivered >= 20:
            kernel.task_exit()

proc demo_run():
    kernel.kernel_init()
    scheduler.sched_add(process.proc_create("consumer", task_consumer, 150))
    scheduler.sched_add(process.proc_create("producer", task_producer, 100))
    scheduler.sched_add(process.proc_create("beta", task_beta, 60))
    scheduler.sched_add(process.proc_create("alpha", task_alpha, 40))
    kernel.kernel_run(1000)
    var st = kernel.kernel_stats()
    print "demo: dispatches=" + str(st["dispatches"])
    print "demo: alpha=" + str(tick_a) + " beta=" + str(tick_b) + " delivered=" + str(delivered)

demo_run()
print "demo: done"