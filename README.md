# SagePocket

**A complete SageLang-based microcomputer platform.**

SagePocket is a miniature, self-contained computer built around the Waveshare
**RP2350-LCD-1.47-A** development board and implemented primarily in **SageLang**.
It is not a firmware demo — it is a real, portable Sage computer with a
bootloader, an operating system, a filesystem, a virtual machine, a graphical
user interface, a command shell, persistent storage, applications, games,
emulators, diagnostics, and its own package format.

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

## Hardware

| Component | Detail |
|-----------|--------|
| Board | Waveshare RP2350-LCD-1.47-A |
| Processor | Raspberry Pi RP2350A (dual Cortex-M33 / dual Hazard3 RISC-V) |
| Clock | Up to 150 MHz |
| SRAM | 520 KB |
| Flash | 16 MB W25Q128-series NOR |
| Display | 172×320 IPS LCD, ST7789V3 controller, SPI |
| Storage | 128 GB microSD / TF card (FAT32, later SageFS) |
| Connectivity | USB 1.1 (device + host) |

See [docs/hardware.md](docs/hardware.md) for the full hardware reference.

## Software Stack

| Component | Description | Docs |
|-----------|-------------|------|
| SageBoot | First Sage-controlled software layer after the RP2350 boot ROM | [docs/boot.md](docs/boot.md) |
| SageOS | Small deterministic embedded kernel | [docs/sageos.md](docs/sageos.md) |
| SageFS | Persistent storage layer (VFS + FAT32, later native SageFS) | [docs/sagefs.md](docs/sagefs.md) |
| SageVM | Portable bytecode virtual machine | [docs/sagevm.md](docs/sagevm.md) |
| SageGUI | Native graphical environment | [docs/sagegui.md](docs/sagegui.md) |
| SageShell | Command shell (LCD terminal + USB serial) | [docs/sageos.md](docs/sageos.md) |
| SageHAL | Hardware abstraction layer | [docs/drivers.md](docs/drivers.md) |
| Applications | Terminal, Calculator, File Manager, Monitor, Paint, Settings | [docs/applications.md](docs/applications.md) |
| Emulators | Sage6502, Apple II, Z80, Game Boy, Sage BASIC | [docs/applications.md](docs/applications.md) |

## Repository Layout

```text
SagePocket/
├── README.md          This file
├── plan.md            Master implementation roadmap
├── docs/              Specifications and design documentation
├── boot/              SageBoot (startup, linker scripts, recovery)
├── kernel/            SageOS kernel (scheduler, memory, IPC, syscalls)
├── drivers/           Hardware drivers (LCD, SD, USB, SPI, ...)
├── sagefs/            Filesystem (VFS, FAT32, block layer, journaling)
├── sagevm/            Virtual machine (bytecode, interpreter, GC, JIT)
├── gui/               SageGUI (framebuffer, graphics, widgets, desktop)
├── shell/             SageShell (command line, parsers)
├── apps/              First-party applications
├── emulators/         Retrocomputer emulation (6502, Z80, Game Boy, BASIC)
├── packages/          .sapp package format, installer, repository
├── tools/             Host + device tools (mkfs, pack, flash, image2sage)
├── tests/             Unit, hardware, and integration tests
├── examples/          Example Sage programs
└── assets/            Fonts, icons, themes, boot assets
```

See [docs/development.md](docs/development.md) for the developer guide and
[plan.md](plan.md) for the complete specification and roadmap.

## Status

SagePocket is at **version 0.1.0** (architecture / implementation plan).
The immediate focus is **Phases 0–3**: repository + build system, hardware
bring-up, LCD, and SD card — the hardware foundation for everything else.

Current milestone progress:

- [x] Repository scaffolding
- [ ] Phase 0 — Repository, build system, documentation, test framework
- [ ] Phase 1 — Hardware bring-up (GPIO, clock, UART, LED, temperature)
- [ ] Phase 2 — LCD (ST7789V3, framebuffer, text, graphics)
- [ ] Phase 3 — SD card (SPI SD, block device, FAT32)
- [ ] Phase 4 — SageBoot (boot menu, loader, recovery, diagnostics)

## Design Principles

1. **Sage-first** — SageLang is the primary implementation language; C/C++ only
   for hardware bootstrap and vendor SDK integration.
2. **Small-core architecture** — small, deterministic, modular, embedded,
   inspectable, portable. Not a Linux reproduction.
3. **Architecture neutrality** — the same application bytecode runs on ARM,
   RISC-V, Linux, Android, Windows, macOS, and the Sage emulator.
4. **Persistent-by-default** — applications and user data live on SageFS, not
   on scarce onboard flash.
5. **Hardware abstraction** — applications never touch RP2350 registers
   directly; they go through the SageOS API → Sage device subsystem →
   driver → hardware chain.

## License

MIT — see [LICENSE](LICENSE).