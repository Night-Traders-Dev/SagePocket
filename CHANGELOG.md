# Changelog

All notable changes to SagePocket are documented in this file.
The format follows common changelog practice; each release groups changes by
**Added**, **Changed**, and **Fixed**.

## [Unreleased]

### Added

- Phase 5 (SageOS kernel, `kernel/`): cooperative priority-based
  round-robin scheduler, task registry (create/exit/wake), virtual ms
  clock + one-shot timers, lowest-fit block memory allocator, IPC
  mailboxes with blocking receive, software IRQ manager with masking +
  deferred work, syscall table dispatcher; `kernel/demo.sage` runs 3
  concurrent tasks (alpha ticks, beta sleeps, producer/consumer over a
  mailbox) on host and pico.
- Phase 5 kernel smoke test (run.sh): emits + compiles + runs the demo on
  host stubs and asserts task counts; unit test `tests/unit/scheduler.sage`
  covers task counts, sleep wake, mailbox handoff.
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

- Host smoke tests now assert the Phase 4 boot flow; kernel demo smoke
  added (33 checks pass total).
- `make arm` / `make rv` build the sageboot UF2s with the Phase 4 flow.
- SageLang compiler upgraded to 4.1.8 (github main, commit `5a7cbb4`);
  the upstream fixes remove the Phase 4/5 backend workarounds:
  `and`/`or` short-circuit in compiled code exactly like the interpreter
  (nil-guard idiom `x == nil or x[field] > 0` is now safe), and a module
  may be imported under multiple aliases in one program without "unknown
  name" errors or duplicate C symbols. Developer prerequisite is now
  `sage >= 4.1.8`.

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