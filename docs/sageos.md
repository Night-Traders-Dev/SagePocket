# SageOS Kernel Specification

> **Version:** 0.1.0 · **Component:** kernel/ · **Related:** [architecture.md](architecture.md)

SageOS is a small, deterministic, modular embedded kernel. It provides
tasking, memory management, IPC, timers, device management, and system
calls on top of SageHAL, and hosts SageVM, SageGUI, and the filesystem.

It is initially a **cooperative/preemptive hybrid** kernel: cooperative
within critical sections, preemptive between tasks on a tick.

---

## 1. Kernel Components

```text
scheduler
task manager
interrupt manager
memory manager
IPC
timers
device manager
VFS
process manager
system calls
power manager
```

Source layout:

```text
kernel/
├── kernel.sage         Kernel entry, initialization, panic
├── scheduler.sage      Task scheduling
├── memory.sage         Physical allocator, kernel heap
├── process.sage        Task/process management
├── ipc.sage            Mailboxes, queues, signals
├── interrupt.sage      Interrupt manager
├── timer.sage          Timers, tick, time service
└── syscall.sage        System call table and dispatch
```

## 2. Task Model

Initial task set:

```text
kernel task
idle task
GUI task
VM task
filesystem task
USB task
shell task
```

Later, applications become independent processes/tasks with their own memory
limits (VM-backed applications are inherently isolated — see
[security.md](security.md)).

## 3. Scheduler

Initial policy: **priority-based round robin**.

### 3.1 Task States

```text
READY
RUNNING
BLOCKED
SLEEPING
TERMINATED
```

### 3.2 Example Priorities

```text
Task                 Priority

kernel               255
filesystem            200
USB                    180
GUI                    150
VM                     120
shell                  100
background              50
idle                     0
```

Priorities are implementation details and must remain configurable.

## 4. Memory Management

The RP2350 provides 520 KB SRAM; memory is partitioned explicitly
(see [hardware.md](hardware.md) §4 and [architecture.md](architecture.md) §6).

Implemented components:

```text
physical allocator
kernel heap
application heap
stack allocator
shared memory
memory statistics
```

### 4.1 Console Command

```text
sage> mem
```

```text
SRAM

Total:       520 KB
Kernel:       72 KB
VM:           96 KB
GUI:          64 KB
Filesystem:   32 KB
Applications: 48 KB
Free:        208 KB
```

## 5. System Calls

Applications communicate with SageOS through system calls. The full
SageVM syscall ABI is specified in [sagevm.md](sagevm.md) §5; the kernel-side
dispatch covers at minimum:

```text
process management     create, exit, kill, yield, sleep
memory                 allocate, free, info
filesystem             open, close, read, write, seek, stat, list
time                   now, uptime
display                framebuffer operations
input                  key/button events
USB                    serial console and dev protocol
system info            CPU, temperature, version
random                 entropy source
```

## 6. Interrupt Management

```text
interrupt manager
 ├── vector setup (per architecture)
 ├── priority assignment
 ├── disable/enable regions (spinlock-safe)
 └── deferred work via kernel tasks
```

Interrupt handlers must be short; heavy work is deferred to kernel tasks so
the hybrid scheduling model stays deterministic.

## 7. Timers and Clock

Exposed to tasks and applications:

```text
time.now()
timer.create()
timer.sleep()
timer.periodic()
```

Shell utilities:

```text
date
time
uptime
```

## 8. IPC

```text
mailboxes
queues
shared memory
events
spinlocks
mutexes
semaphores
```

Multicore variants (later): see [architecture.md](architecture.md) §7.

## 9. Device Management

The kernel hosts a device manager:

```text
device manager
 ├── device registry (name → driver)
 ├── open/close/ioctl routing
 ├── attach/detach
 └── integrated with VFS (devices appear as files where useful)
```

Applications access devices only via the SageOS API; they never touch
RP2350 registers (see [drivers.md](drivers.md)).

## 10. Power Management

States:

```text
active
idle
sleep
dormant
```

Services request states explicitly:

```text
power.keep_awake()
power.allow_sleep()
```

The LCD backlight is independently controllable.

## 11. Watchdog

The kernel periodically feeds the watchdog. If the system becomes
unresponsive:

```text
watchdog
    ↓
reset
    ↓
SageBoot
    ↓
crash recovery
```

Boot statistics (`boot_count`, `crash_count`, `last_reset_reason`) are
persisted by SageBoot — see [boot.md](boot.md) §7.

## 12. Panic and Crash Handling

Kernel faults enter:

```text
SAGEOS KERNEL PANIC
```

Reporting:

```text
PC
SP
registers
task
fault code
stack trace
```

Application faults are handled by SageVM (terminate → release memory →
crash log → return to desktop) — see [security.md](security.md).

## 13. Logging

Kernel and subsystems log to SageFS:

```text
/logs/kernel.log
/logs/boot.log
/logs/sagevm.log
/logs/sagefs.log
/logs/gui.log
```

Shell commands:

```text
log
log kernel
log boot
log clear
```

## 14. Definitions of Done (per milestone)

### SagePocket 0.2 (kernel milestone)

```text
scheduler
memory
tasks
timers
```

Exit criteria: multiple SageOS tasks run simultaneously.

### Multicore (SagePocket 0.7)

```text
SMP
IPC
task affinity
```

Split: Core 0 runs kernel/filesystem/interrupts; Core 1 runs VM/GUI/apps.

Related docs: [architecture.md](architecture.md), [sagevm.md](sagevm.md),
[sagefs.md](sagefs.md), [drivers.md](drivers.md), [security.md](security.md).