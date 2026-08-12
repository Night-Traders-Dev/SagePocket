# Changelog

All notable changes to SagePocket are documented in this file.
The format follows common changelog practice; each release groups changes by
**Added**, **Changed**, and **Fixed**.

## [Unreleased]

### Added

- Phase 4: boot menu (boot kernel / recovery / diagnostics / halt) in
  `boot/sageboot.sage` v0.4.0, kernel loader for `SAGEOS.KRN` from SD+FAT32
  (size + CRC16 verify), recovery re-diagnostics, UART0 menu input with
  default-boot timeout; drivers imported from repo root CWD.
- Phase 3: full SD/SPI driver (`drivers/sd/sd_spi.sage`) with byte-at-a-time
  R1 polling and FAT32 filesystem driver (`drivers/fs/fat32.sage`) - mount,
  directory listing, file read/write.
- Repository scaffolding per the plan's Phase 0:
  - Complete directory layout (`boot/`, `kernel/`, `drivers/`, `sagefs/`,
    `sagevm/`, `gui/`, `shell/`, `apps/`, `emulators/`, `packages/`,
    `tools/`, `tests/`, `examples/`, `assets/`)
  - Initial documentation set in `docs/` (architecture, hardware, boot,
    sageos, sagefs, sagevm, sagegui, drivers, applications, security,
    development)
  - `README.md`, `LICENSE`, `CHANGELOG.md`, `UPDATES.md`
  - Source stubs for the planned modules

### Changed

- Host smoke tests now assert the Phase 4 boot flow; 25 checks pass.
- `make arm` / `make rv` build the sageboot UF2s with the Phase 4 flow.

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