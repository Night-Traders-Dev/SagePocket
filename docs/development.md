# SagePocket Developer Guide

> **Version:** 0.1.0 · **Status:** Phase 0 (repository + build system + documentation)

This document describes how SagePocket is built, tested, and developed: the
repository reference, development phases, build system plan, testing
strategy, and the immediate implementation order.

---

## 1. Prerequisites

```text
SageLang toolchain (sage compiler + sagevm) — v4.x per the Sage ecosystem
RP2350 toolchain for the chosen architecture:
  ARM:    arm-none-eabi-gcc + CMake (Pico SDK)
  RISC-V: riscv toolchain for Hazard3
Python 3 (build orchestration)
```

The board's official examples (FAT32 TF-card and LCD) are the bootstrap
references for Phase 2 and Phase 3 — see [hardware.md](hardware.md).

## 2. Repository Reference

```text
SagePocket/
│
├── README.md           Project overview
├── LICENSE             MIT license
├── plan.md             Master specification and roadmap
├── CHANGELOG.md        Release changes
├── UPDATES.md          Development log
│
├── docs/               Specifications (this document set)
│
├── boot/               SageBoot
│   ├── sageboot.sage
│   ├── startup/
│   ├── linker/         Linker scripts (ARM + RISC-V)
│   └── recovery/
│
├── kernel/             SageOS kernel
│   ├── kernel.sage
│   ├── scheduler.sage
│   ├── memory.sage
│   ├── process.sage
│   ├── ipc.sage
│   ├── interrupt.sage
│   ├── timer.sage
│   └── syscall.sage
│
├── drivers/            Drivers and SageHAL
│   ├── lcd/st7789v3.sage
│   ├── sd/sd_spi.sage
│   ├── usb/  gpio/  uart/  spi/  i2c/  pwm/  adc/  pio/
│   ├── rgb/
│   └── temperature/
│
├── sagefs/             Filesystem
│   ├── vfs.sage  fat32.sage  inode.sage  block.sage
│   ├── cache.sage  journal.sage  sagefs.sage
│
├── sagevm/             Virtual machine
│   ├── vm.sage  bytecode.sage  interpreter.sage  memory.sage
│   ├── gc.sage  syscall.sage  loader.sage
│   └── jit/
│
├── gui/                SageGUI
│   ├── framebuffer.sage  graphics.sage  font.sage  widgets.sage
│   ├── window.sage  menu.sage  shell_ui.sage  desktop.sage
│
├── shell/              SageShell
│   ├── shell.sage
│   ├── commands/
│   └── parser.sage
│
├── apps/               First-party applications
│   ├── terminal/  calculator/  fileman/  monitor/
│   ├── paint/  settings/  system/  games/
│
├── emulators/          Retrocomputing
│   ├── sage6502/  apple2/  z80/  gameboy/  basic/
│
├── packages/           Package system
│   ├── format/  installer/  repository/
│
├── tools/              Host + device tools
│   ├── image2sage/  font2sage/
│   ├── mkfs.sage/  mkapp.sage/  pack.sage/  flash.sage/  monitor.sage
│
├── tests/              Test suites
│   ├── unit/  hardware/  sagefs/  sagevm/  gui/  integration/
│
├── examples/           Example programs
│   ├── hello.sage  lcd.sage  sd.sage  gui.sage  app.sage
│
└── assets/             Assets
    ├── fonts/  icons/  themes/  boot/
```

## 3. Build System (planned)

A `sagemake` orchestrator (mirroring the SageVM project's tooling) will
provide:

```text
sagemake build              build all
sagemake install            install to /usr/local
sagemake arm                build sagepocket-arm image
sagemake riscv              build sagepocket-rv image
sagemake test               run test suites
sagemake flash              flash to board (via sagectl / picotool-style)
sagemake image              build sagepocket.img system image
```

Build targets:

```text
sagepocket-arm      ARM Cortex-M33 firmware + system image
sagepocket-rv       Hazard3 RISC-V firmware + system image
sagepocket-vm       Host-side runtime (SageVM on the host)
```

## 4. Development Phases

| Phase | Deliverable | Exit criteria |
|-------|-------------|---------------|
| 0 | Repository, build system, docs, hardware definitions, test framework | Clean repository builds |
| 1 | Hardware bring-up: startup, GPIO, clock, UART, LED, temperature | RP2350 executes Sage-controlled firmware |
| 2 | LCD: ST7789V3, SPI, framebuffer, text, graphics primitives | SageBoot displays diagnostics |
| 3 | SD: SPI SD, block device, FAT32, read/write, directory enumeration | `sage> ls` works from the physical SD card |
| 4 | SageBoot: boot menu, kernel loader, recovery, diagnostics | SageBoot loads SageOS from storage |
| 5 | SageOS kernel: scheduler, tasks, interrupts, memory, timers, IPC | Multiple tasks run simultaneously |
| 6 | SageFS: VFS, FAT32 backend, cache, file descriptors, directories | SageOS has a persistent filesystem |
| 7 | SageShell: terminal, commands, USB console | `sage>` works locally and over USB |
| 8 | SageVM: bytecode, interpreter, loader, memory, syscalls | `hello.sbc` runs on the board |
| 9 | Sage applications: Calculator, File Manager, Monitor, Terminal, Settings, Paint | Usable without a host computer |
| 10 | SageGUI: desktop, windows, widgets, menus, icons | Boots directly into a graphical desktop |
| 11 | Packages: `.sapp`, manifest, installer, manager, permissions | Third-party apps installable |
| 12 | Multicore: core management, IPC, affinity | Work distributed across both cores |
| 13 | RISC-V: port boot/HAL/kernel/drivers to Hazard3 | ARM and RISC-V builds run same apps |
| 14 | Retrocomputing: Sage6502, SageApple, Z80, Game Boy, BASIC | Emulators execute from `/roms/` |
| 15 | Native compilation: ARM and RISC-V backends | Apps run without the VM when compiled natively |
| 16 | Native SageFS: replace FAT32, retain compatibility | Survives power-loss and corruption tests |

## 5. Immediate Implementation Order

Do **not** implement everything simultaneously. Follow `plan.md` §73:

```text
01. Create SagePocket repository        ← current
02. Add RP2350 hardware definitions
03. Create minimal SageBoot
04. Blink RGB LED
05. Initialize UART
06. Initialize clock
07. Initialize SRAM
08. Implement ST7789V3 driver
09. Display SageBoot screen
10. Implement SD SPI driver
11. Read SD sectors
12. Implement FAT32 read-only support
13. Implement FAT32 write support
14. Create SageFS VFS
15. Build SageOS kernel
16. Add scheduler
17. Add memory allocator
18. Add timers
19. Add task system
20. Implement SageShell
21. Implement SageVM
22. Run first .sbc
23. Implement system calls
24. Implement SageGUI
25. Build desktop
26-29. Calculator, File Manager, Monitor, Settings
30. Implement .sapp
31. Implement application manager
32. Implement USB sagectl
33. Implement multicore support
34-35. Port SageBoot/SageOS to Hazard3
36. Run identical VM apps on both
37-41. Sage6502, SageApple, Sage BASIC, Z80, Game Boy
42-43. Native ARM and RISC-V backends
44-45. Native SageFS + journaling
46. Crash recovery
47. Security/sandboxing
48-49. Optimize VM and GUI
50. Release SagePocket 1.0
```

## 6. Testing Strategy

### Unit Tests (`tests/unit/`)

```text
parser
bytecode
VM
filesystem
graphics
memory
scheduler
```

Run on the host (SageVM on the host) — no hardware required.

### Hardware Tests (`tests/hardware/`)

```text
LCD
SD
SPI
USB
GPIO
temperature
RGB
```

Run on the board; results over UART/USB.

### Integration Tests (`tests/integration/`)

```text
boot → filesystem
filesystem → VM
VM → GUI
GUI → applications
USB → shell
```

### Stress Tests

```text
filesystem write/read loops
VM allocation loops
task creation loops
GUI rendering loops
multicore stress
SD power-loss simulation
```

### Fault Injection

Deliberately test (see [security.md](security.md) §9):

```text
corrupt kernel / application / fs metadata
SD removal during read / write
VM out-of-memory
invalid bytecode
stack overflow
heap exhaustion
task deadlock
watchdog timeout
```

The system must recover whenever possible.

## 7. Performance Validation

Track against engineering targets:

```text
Boot to SageBoot:   < 1 second
Boot to SageOS:     < 3 seconds
Boot to GUI:        < 5 seconds
Shell response:     < 50 ms
GUI:                30+ FPS
```

Filesystem: *stable before fast*. VM: *correctness before performance*.

## 8. Coding Conventions

- All new code in SageLang (see `SageLang_Reference.md` in the repo root).
- C/C++ only for hardware bootstrap, vendor SDK integration, ROM/startup,
  and reference implementations.
- Follow the module boundaries in `docs/architecture.md` — no cross-layer
  register access.
- 100% of new functionality lands with tests.

## 9. Documentation Checklist

Required documentation (per `plan.md` §63) and where it lives:

| Document | Location |
|----------|----------|
| SagePocket Architecture | `docs/architecture.md` |
| SageBoot Specification | `docs/boot.md` |
| SageOS Kernel API | `docs/sageos.md` |
| SageFS Specification | `docs/sagefs.md` |
| SageVM Bytecode Specification | `docs/sagevm.md` |
| SageGUI API | `docs/sagegui.md` |
| Sage Application Specification | `docs/applications.md` |
| Sage Device Driver API | `docs/drivers.md` |
| SagePocket Hardware Reference | `docs/hardware.md` |
| SagePocket Developer Guide | `docs/development.md` |
| SagePocket User Guide | (user-facing, later phase) |

Related docs: [architecture.md](architecture.md), [plan.md](../plan.md).