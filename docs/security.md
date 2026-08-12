# SagePocket Security Model

> **Version:** 0.1.0 · **Component:** packages/, sagevm/, kernel/ · **Related:** [architecture.md](architecture.md)

This document defines the security model of SagePocket: application
permissions, sandboxing, crash recovery, fault handling, and watchdog
behavior. The guiding rule is that SagePocket must recover from any
application-level fault without a reboot, and detect system-level faults
through the watchdog path.

---

## 1. Threat Model (Scope)

SagePocket is an embedded, single-user platform. The initial security goals:

1. Applications cannot crash or corrupt the kernel or other applications.
2. Applications cannot access hardware except through granted permissions.
3. Applications cannot modify system files without authorization.
4. System integrity can be restored through Recovery Mode even when
   applications or the kernel on disk are corrupted.

Trusted: SageBoot, kernel, first-party system components.
Untrusted: installed third-party applications.

## 2. Application Permissions

Applications declare permissions in the `.sapp` manifest:

```text
permissions =
    display
    filesystem
    usb
    network
    hardware
```

Permissions are checked by the kernel at syscall boundary and enforced by the
Application Manager at install time.

A request for sensitive permissions (e.g. `hardware`) may require user
confirmation at first run:

```text
Calculator requests:

[ ] Filesystem
[✓] Display

Allow?
YES / NO
```

## 3. Application Sandboxing

VM applications are sandboxed by construction. Each application receives:

```text
virtual memory
virtual filesystem namespace
system-call interface
```

instead of unrestricted hardware access. For example, an application
installed to:

```text
/apps/calculator/
```

cannot modify:

```text
/system/
```

Sandbox properties:

- **Memory isolation**: the VM enforces the application's memory limit
  (manifest `memory = 32K`); no guest code can address memory outside its
  VM heap.
- **Filesystem namespace**: reads/writes are confined to the application's
  declared area plus explicitly granted paths.
- **Syscall filtering**: only approved syscall classes execute — each maps
  to a declared permission.

## 4. Crash Recovery

### 4.1 Application Fault

```text
Application fault
      ↓
SageVM detects fault
      ↓
terminate application
      ↓
release memory
      ↓
write crash log
      ↓
return to desktop
```

A crash log entry is appended to `/logs/` (kernel, sagevm, sagefs, gui)
for diagnosis.

### 4.2 Kernel Fault

Kernel faults enter:

```text
SAGEOS KERNEL PANIC
```

with:

```text
PC
SP
registers
task
fault code
stack trace
```

## 5. Watchdog

The kernel periodically feeds the watchdog. On unresponsiveness:

```text
watchdog
    ↓
reset
    ↓
SageBoot
    ↓
crash recovery
```

SageBoot persists boot statistics:

```text
boot_count
crash_count
last_reset_reason
```

An elevated crash count routes the boot straight into Recovery Mode.

## 6. Recovery and Integrity

Recovery Mode (see [boot.md](boot.md) §4) is the last line of defense:

```text
mount SD
inspect filesystem
copy kernel
delete broken application
restore configuration
format SageFS
install system image
run diagnostics
reboot
```

The kernel image is validated before execution; a corrupt kernel
automatically enters Recovery Mode rather than executing.

## 7. Invalid Input Defense

The VM loader must reject:

```text
invalid bytecode
out-of-bounds jump targets
malformed constant pools
oversized programs
```

The filesystem must tolerate:

```text
corrupt metadata
removal of SD during read/write
power loss during write
```

See [sagevm.md](sagevm.md) §7 and [sagefs.md](sagefs.md) §9.

## 8. Logging and Audit

Logs:

```text
/logs/kernel.log
/logs/boot.log
/logs/sagevm.log
/logs/sagefs.log
/logs/gui.log
```

Commands: `log`, `log kernel`, `log boot`, `log clear`.

## 9. Fault Injection Testing

The system must be deliberately tested against:

```text
corrupt kernel
corrupt application
corrupt filesystem metadata
remove SD during read
remove SD during write
VM out-of-memory
invalid bytecode
stack overflow
heap exhaustion
task deadlock
watchdog timeout
```

and must recover whenever possible. See [development.md](development.md) §6.

## 10. Definitions of Done

- [ ] Installed applications cannot modify `/system/` or other apps' data
- [ ] Permission enforcement at the syscall boundary
- [ ] Application crashes return to the desktop without reboot
- [ ] Watchdog + crash counters route to Recovery Mode
- [ ] Fault-injection suite passes (recovery whenever possible)

Related docs: [boot.md](boot.md), [sageos.md](sageos.md), [sagevm.md](sagevm.md),
[sagefs.md](sagefs.md), [applications.md](applications.md).