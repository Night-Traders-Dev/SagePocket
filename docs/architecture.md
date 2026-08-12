# SagePocket Architecture

> **Version:** 0.1.0 · **Status:** Architecture / Implementation Plan
> **Target:** Waveshare RP2350-LCD-1.47-A (RP2350A)

This document describes the overall architecture of the SagePocket platform.
It is the top-level design document and should be read together with the
[master plan](../plan.md) and the component specifications in this `docs/`
folder.

---

## 1. System Stack

SagePocket is organized as seven major layers. Each layer depends only on the
layer below it.

```text
Layer 7     Applications
               │
Layer 6     SageGUI / SageShell
               │
Layer 5     SageVM
               │
Layer 4     SageOS
               │
Layer 3     SageFS
               │
Layer 2     Drivers / HAL
               │
Layer 1     SageBoot / Hardware
```

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| 7 | Applications | User-facing programs, games, emulators |
| 6 | SageGUI / SageShell | Graphical environment and command interface |
| 5 | SageVM | Portable execution of Sage bytecode |
| 4 | SageOS | Kernel: scheduling, memory, IPC, device management |
| 3 | SageFS | Persistent, hierarchical storage (VFS + filesystem drivers) |
| 2 | Drivers / SageHAL | Hardware abstraction over the RP2350 peripherals |
| 1 | SageBoot / Hardware | Bootloader and physical hardware |

```text
                    SageLang
                       │
                       ▼
                 Sage Compiler
                       │
                       ▼
                  Sage Bytecode
                       │
                       ▼
                     SageVM
                       │
                       ▼
                     SageOS
              ┌─────────┼─────────┐
              │         │         │
           SageGUI   SageShell  Services
              │         │         │
              └─────────┼─────────┘
                       │
                    SageFS
                       │
                       ▼
                    128 GB SD
                       │
                       ▼
                  SagePocket HW
```

---

## 2. Design Principles

1. **Sage-first.** SageLang is the primary implementation language. C/C++ is
   restricted to hardware bootstrap, vendor SDK integration, unavoidable
   ROM/startup requirements, reference implementations, and debugging. The
   long-term objective is that *everything* — bootloader, OS, filesystem, VM,
   GUI, applications, tools — is written in Sage.

2. **Small-core architecture.** SageOS is small, deterministic, modular,
   embedded, inspectable, and portable. It does not attempt to reproduce
   Linux.

3. **Architecture neutrality.** The same application bytecode executes on the
   RP2350 ARM build, the RP2350 RISC-V build, Linux, Android, Windows, macOS,
   and the Sage emulator — wherever a SageVM runtime exists.

4. **Persistent-by-default.** Applications and user data live on SageFS
   (the microSD card), not on the scarce 16 MB onboard flash.

5. **Hardware abstraction.** Applications never manipulate RP2350 registers.
   All hardware access flows through the SageOS API → Sage device subsystem →
   driver → hardware chain.

```text
Application
    ↓
SageOS API
    ↓
Sage device subsystem
    ↓
RP2350 driver
    ↓
Hardware
```

---

## 3. Module Map

The repository layout maps one-to-one onto the architecture:

| Directory | Architecture role |
|-----------|-------------------|
| `boot/` | Layer 1 — SageBoot, startup code, linker scripts, recovery |
| `kernel/` | Layer 4 — SageOS kernel |
| `drivers/` | Layer 2 — SageHAL and device drivers |
| `sagefs/` | Layer 3 — filesystem (VFS, FAT32, block layer, journaling) |
| `sagevm/` | Layer 5 — virtual machine (interpreter, GC, JIT, loader) |
| `gui/` | Layer 6 — SageGUI (framebuffer, widgets, desktop) |
| `shell/` | Layer 6 — SageShell (command parser, builtins) |
| `apps/` | Layer 7 — first-party applications |
| `emulators/` | Layer 7 — retrocomputer emulation |
| `packages/` | `.sapp` packaging, installer, repository |
| `tools/` | Host side of the developer workflow |
| `tests/` | Unit, hardware, integration tests |

See [development.md](development.md) for the full repository reference.

---

## 4. Dual-Architecture Strategy

The RP2350 uniquely offers a choice between dual **Cortex-M33** (ARM) and dual
**Hazard3** (RISC-V) processors, selected during boot.

SagePocket therefore maintains **two official builds**:

```text
sagepocket-arm     → Cortex-M33
sagepocket-rv      → Hazard3 RISC-V
```

### Shared across both targets

Only the lowest architecture-dependent layer differs. Every layer above it
must be shared:

```text
SageOS API
SageFS
SageVM bytecode
SageGUI
applications
shell
configuration
```

### ARM build

- Mature toolchain
- Hardware floating point
- DSP instructions
- Broad ecosystem

### RISC-V build

- Open ISA
- Exercises the Sage RISC-V backend
- Direct integration with existing Sage RISC-V work
- Architecture experimentation

---

## 5. Hardware Abstraction (SageHAL)

Drivers and the kernel expose hardware through a single abstraction layer.
Applications must never depend on RP2350 register definitions.

```text
hal.cpu()
hal.memory()
hal.gpio()
hal.spi()
hal.i2c()
hal.uart()
hal.pwm()
hal.adc()
hal.timer()
hal.usb()
hal.pio()
hal.temperature()
```

Example — application-facing display API:

```text
lcd.init()
lcd.clear()
lcd.pixel(x, y, color)
lcd.rectangle(...)
lcd.text(...)
lcd.flush()
```

rather than:

```text
RP2350.SPI0.CS = ...
```

---

## 6. Memory Strategy

The RP2350 provides **520 KB SRAM** — a tight budget that must be partitioned
explicitly. The initial conceptual layout:

```text
520 KB SRAM
│
├── Kernel
├── Kernel heap
├── Task stacks
├── SageVM
├── GUI buffers
├── filesystem cache
├── DMA buffers
└── application memory
```

Target resource budget (section 57 of `plan.md`):

```text
SRAM
────────────────────────────

Kernel                 64 KB
SageVM                  96 KB
GUI                     80 KB
Filesystem              32 KB
Drivers                 32 KB
Tasks                   64 KB
Buffers                 32 KB
Free                    120 KB
```

Budget figures are engineering targets and must be validated experimentally.

The full 172×320 RGB565 framebuffer is ~107.5 KiB and should **not** be
permanently allocated unless the memory profile proves it worthwhile —
partial/tiled rendering is the default GUI mode.

See [sageos.md](sageos.md) for the memory manager design and
[sagegui.md](sagegui.md) for the framebuffer strategy.

---

## 7. Multicore Model

Initially SagePocket uses a single core. Once stable, the recommended split:

```text
CORE 0                          CORE 1
SageOS kernel                   SageVM
filesystem                      GUI
interrupts                      applications
```

Later, optional task affinity:

```text
task.cpu = 0
task.cpu = 1
task.cpu = any
```

Multicore IPC primitives: mailboxes, queues, shared memory, events,
spinlocks, mutexes, semaphores.

---

## 8. Package and Application Flow

Sage applications are developed on a host, compiled to Sage bytecode, packed
into a `.sapp` package, and transferred to the device over USB.

```text
SageLang source
       ↓
Sage compiler
       ↓
SageVM bytecode
       ↓
.sapp
       ↓
sagectl upload
       ↓
USB
       ↓
SagePocket (SageOS → SageFS → Application Manager → SageVM)
```

On the device, the Application Manager stores packages under `/apps/` and
launches them through SageVM. See [applications.md](applications.md).

---

## 9. Future Architecture Expansions

These features are deliberately designed *for* but not *into* the initial
implementation:

- **SageNet** — sockets, TCP, UDP, DNS, HTTP, SageRPC (future hardware:
  ESP32, Ethernet, Wi-Fi, USB network adapter)
- **Distributed SageFS** — local, removable, and *remote* backing stores
  (SD, NAS, SageFS node, SageCloud)
- **SageRPC** — device-to-device communication between Sage computers

The OS design must keep these extensions possible without complicating the
initial embedded system.

---

## 10. Related Documents

| Document | Purpose |
|----------|---------|
| [hardware.md](hardware.md) | Physical platform reference |
| [boot.md](boot.md) | SageBoot specification |
| [sageos.md](sageos.md) | Kernel, scheduler, memory, tasks |
| [sagefs.md](sagefs.md) | Filesystem specification |
| [sagevm.md](sagevm.md) | Virtual machine specification |
| [sagegui.md](sagegui.md) | Graphical environment |
| [drivers.md](drivers.md) | Driver and SageHAL interfaces |
| [applications.md](applications.md) | Applications, packages, emulators |
| [security.md](security.md) | Permissions, sandboxing, recovery |
| [development.md](development.md) | Developer guide, phases, testing |
| [plan.md](../plan.md) | Master specification and roadmap |