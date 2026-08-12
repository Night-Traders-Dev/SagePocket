# Changelog

All notable changes to SagePocket are documented in this file.
The format follows common changelog practice; each release groups changes by
**Added**, **Changed**, and **Fixed**.

## [Unreleased]

### Added

- Repository scaffolding per the plan's Phase 0:
  - Complete directory layout (`boot/`, `kernel/`, `drivers/`, `sagefs/`,
    `sagevm/`, `gui/`, `shell/`, `apps/`, `emulators/`, `packages/`,
    `tools/`, `tests/`, `examples/`, `assets/`)
  - Initial documentation set in `docs/` (architecture, hardware, boot,
    sageos, sagefs, sagevm, sagegui, drivers, applications, security,
    development)
  - `README.md`, `LICENSE`, `CHANGELOG.md`, `UPDATES.md`
  - Source stubs for the planned modules

## [0.0.1] - 2026

### Added

- `plan.md` — complete project specification and implementation roadmap for
  the Waveshare RP2350-LCD-1.47-A microcomputer platform.

---

## Version Roadmap

| Version | Milestone |
|---------|-----------|
| 0.1 | Hardware bring-up: SageBoot, LCD, SD, LED, UART |
| 0.2 | Kernel: scheduler, memory, tasks, timers |
| 0.3 | Filesystem: SageFS/VFS, FAT32, shell |
| 0.4 | VM: SageVM, bytecode, applications |
| 0.5 | GUI: SageGUI, desktop, file manager |
| 0.6 | Application ecosystem: .sapp, installer, package manager |
| 0.7 | Multicore: SMP, IPC, task affinity |
| 0.8 | RISC-V: Hazard3 SageBoot and SageOS |
| 0.9 | Retrocomputing: Sage6502, SageApple, Z80, Game Boy |
| 1.0 | Complete platform |