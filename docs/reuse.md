# Component Reuse Map

SagePocket does not reimplement platform components that already exist in
the sibling Sage repos. Each repo below lives in `~/Devel` and is
developed upstream; SagePocket consumes them as documented, and anything
it ports carries a sync recipe.

## Upstream mapping

| SagePocket component | Upstream repo | Relationship |
|---|---|---|
| `sagevm/` (Phase 8) | [SageVM](https://github.com/Night-Traders-Dev/SageVM) | Port / vendor. The upstream `sagevm_standalone.sage` is the authoritative VM (SVM + SRVM, self-hosting); the pocket's copy is a synchronized port (see `sagevm/sagevm.sage` header). |
| `sagevm/` bytecode format | SageVM `docs/SPEC.md` | The runtime format `sage --sgvm` emits and the MetalVM executes. `tools/parity_check.py` there is the conformance tool. |
| `boot/` (Phases 1-4) | [SageBoot](https://github.com/Night-Traders-Dev/SageBoot) | Architecture reference. Upstream is a modular multi-arch bootloader (rv64/arm64/x64/rp2040/rp2350) with an rp2350 port and test suite; SagePocket's `boot/sageboot.sage` is its device-specific bring-up (LCD menu, recovery, kernel loader) and stays in-tree. |
| Filesystem layer | [SageFS](https://github.com/Night-Traders-Dev/SageFS) | NOT reusable in the pocket. Upstream SageFS is a Linux host filesystem (FUSE + io_uring + CoW b-trees). SagePocket's storage stack (`sagefs/` + `drivers/fs/fat32.sage`) targets the RP2350 SD card; no shared code is expected. |
| Toolchain | [SageLang](https://github.com/Night-Traders-Dev/SageLang) | The `sage` binary used throughout. Development prerequisite: `sage >= 4.1.8`. |
| Workspace glue | [SageOS](https://github.com/Night-Traders-Dev/SageOS) | Vendors SageLang/SageVM/SageBoot via `sync_sage.py`; reference for how the pocket should pull sibling sources. |

## Known upstream issues (checked 2026-08-12)

- **Bytecode version drift (RESOLVED for the pocket).** `sage --sgvm`
  emission changed between compiler versions (4.1.7 emits 40-byte files
  with string constant type 0x0f, 4.1.8 emits 44-byte files with type
  0x04) and neither parses under the SageVM v1.0.0 binaries ("Invalid
  constant type: 4/15", "768 constants"; even `kernel.sgvm` fails on the
  vendored `.deps/sgvm`). **The pocket does not use the outer compiler
  for bytecode.** It uses the VM's self-hosting path instead:
  `/usr/local/bin/sagevm compile` (installed binary) emits bytecode its
  own engine parses — verified end-to-end in the pocket interpreter, see
  `sgvm_smoke` in tests/run.sh. The upstream drift remains open as an
  upstream coordination item (pin one SageLang commit and rebuild the
  emitter + engine together).
- **Vendored VM port seams.** The standalone relies on host-registered
  names that only exist in the compiled binary (`sgvm_vm`, hexdump
  modules) and on `thread.lock(g_gil)`. `tools/compose_sagevm.py`
  applies three documented seams to the composed copy only; the vendored
  file stays byte-identical for parity.
- SageFS upstream is host-only (FUSE); if an embedded volume layer is
  ever wanted on the pocket it should be a new consumer, not a fork.

## Sync policy

- Pockets ports record the upstream commit in the file header.
- Anything that must track upstream is refreshed at the start of the
  phase that consumes it, using the upstream `tools/` conformance suite
  (e.g. SageVM `parity_check.py`) as the gate.