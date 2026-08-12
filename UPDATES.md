# Updates

Development log for SagePocket. Entries are appended as work progresses; the
most recent entry is at the top. This file tracks *what happened and why*,
while [CHANGELOG.md](CHANGELOG.md) tracks released changes.

---

## 2026-08-11 — Initial repository scaffolding (Phase 0 start)

- Created the full repository layout defined in section 4 of `plan.md`:
  all top-level modules (`boot/`, `kernel/`, `drivers/`, `sagefs/`,
  `sagevm/`, `gui/`, `shell/`, `apps/`, `emulators/`, `packages/`,
  `tools/`, `tests/`, `examples/`, `assets/`) plus `docs/`.
- Wrote the documentation set:
  - `architecture.md` — the seven-layer system architecture
  - `hardware.md` — RP2350-LCD-1.47-A hardware reference
  - `boot.md` — SageBoot specification (boot flow, boot menu, recovery)
  - `sageos.md` — SageOS kernel specification (scheduler, memory, tasks)
  - `sagefs.md` — SageFS specification (VFS, FAT32, native filesystem)
  - `sagevm.md` — SageVM specification (bytecode, memory, syscalls, GC)
  - `sagegui.md` — SageGUI specification (desktop, widgets, graphics)
  - `drivers.md` — driver and SageHAL API documentation
  - `applications.md` — app ecosystem, .sapp format, emulators
  - `security.md` — permissions, sandboxing, recovery
  - `development.md` — developer guide, phases, testing, build system
- Wrote `README.md`, `LICENSE` (MIT, matching SageLang/SageVM), and
  `CHANGELOG.md`.
- Added source stubs for planned `.sage` modules.

**Next up:** Phase 0 hardware definitions (RP2350 register/board layout),
build system, and test framework — then Phase 1 hardware bring-up
(startup, GPIO, clock, UART, LED, temperature) per the immediate
implementation order in `plan.md` §73.
## 2026-08-12 — Phase 4: boot menu, kernel loader, recovery (SageBoot v0.4.0)

- SageBoot now brings up storage (SD init -> FAT32 mount -> root listing ->
  find SAGEOS.KRN) then runs a boot menu over UART0: 1 boot kernel (default
  after ~9 s timeout), 2 recovery, 3 diagnostics, 0 halt to console.
- `kernel_loader` reads SAGEOS.KRN from the SD card via the FAT driver and
  verifies size + CRC16 before the Phase 5 hand-off.
- Fixed the sd_cmd R1 read: byte-at-a-time polling instead of a 32-byte
  batch read that could swallow the 0xFE data token for CMD17/CMD24.
- Pico-C emitter limitation found: a module imported under two different
  aliases in one program breaks emission ("unknown name 'sd'"); workaround:
  import `drivers.sd.sd_spi as sd` (the same alias fat32.sage uses).
- Host smoke now asserts "SageBoot Phase 4 bring-up complete.", "Boot menu:"
  and the no-kernel fallback; 25 checks pass, 0 failed.
- SD image validated: SAGEOS.KRN written with tests/mkimg.py, fsck.fat
  clean, file content md5 matches on loop mount.
- Committed as bb5df37 (phase 3 final) + phase 4 work.
