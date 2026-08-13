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

- **Bytecode version drift.** `sage --sgvm <src> -o out.sgvm` from the
  installed compiler (4.1.8) produces a `.sgvm` (44 bytes for "hello")
  that the SageVM v1.0.0 release binary reports as `Invalid constant
  type: 4` / "768 constants". SageVM documents `>= 4.1.2` but its release
  binaries and in-repo `.deps` toolchains are mutually inconsistent
  (even `kernel.sgvm` fails on the vendored `core/sgvm`). Before Phase 8
  lands, the pocket toolchain and SageVM must pin **one** SageLang commit
  and rebuild SageVM's `--sgvm` path and engine together.
- SageFS upstream is host-only (FUSE); if an embedded volume layer is
  ever wanted on the pocket it should be a new consumer, not a fork.

## Sync policy

- Pockets ports record the upstream commit in the file header.
- Anything that must track upstream is refreshed at the start of the
  phase that consumes it, using the upstream `tools/` conformance suite
  (e.g. SageVM `parity_check.py`) as the gate.