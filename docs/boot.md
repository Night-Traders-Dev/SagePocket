# SageBoot Specification

> **Version:** 0.1.0 · **Component:** boot/ · **Related:** [architecture.md](architecture.md)

SageBoot is the first Sage-controlled software layer after the RP2350 boot
ROM. It initializes the hardware, locates and validates SageOS, and transfers
control to the kernel. It also provides the boot menu, hardware diagnostics,
and an independent recovery environment.

---

## 1. Responsibilities

1. Initialize the execution environment
2. Initialize clocks
3. Establish memory
4. Identify CPU architecture
5. Initialize basic peripherals
6. Initialize the display
7. Detect the SD card
8. Locate SageOS
9. Validate SageOS
10. Load SageOS
11. Transfer control to SageOS

## 2. Boot Flow

```text
RESET
  │
  ▼
RP2350 ROM
  │
  ▼
SageBoot
  │
  ├── hardware detection
  ├── architecture detection
  ├── memory initialization
  ├── clock initialization
  ├── LCD initialization
  ├── SD initialization
  │
  ▼
SageFS mount
  │
  ▼
/system/kernel
  │
  ▼
kernel validation
  │
  ▼
SageOS
```

The RP2350 ROM loads firmware from onboard flash (SageBoot lives at the
start of the flash layout). SageBoot then brings up clocks, SRAM, UART,
LCD, and the SD card; mounts the filesystem; loads the kernel image from
`/system/kernel`; validates it (checksum/signature); and jumps to SageOS.

## 3. Boot Menu

If a boot key is held or a recovery condition is detected, SageBoot presents:

```text
SAGEBOOT

1. Boot SageOS
2. Boot SageVM
3. Hardware Diagnostics
4. Recovery
5. SD Tools
6. Architecture Test
7. Reboot
```

| Item | Purpose |
|------|---------|
| Boot SageOS | Normal boot path |
| Boot SageVM | Start the VM directly (no kernel services) |
| Hardware Diagnostics | Run the diagnostic suite (see [hardware.md](hardware.md)) |
| Recovery | Enter the recovery environment |
| SD Tools | SD diagnostics: sdinfo, sdtest, sdspeed, sdfmt |
| Architecture Test | CPU architecture detection/selection (ARM vs RISC-V) |
| Reboot | Reset the board |

## 4. Recovery Mode

Recovery must remain functional even if SageOS (or the kernel on flash) is
corrupted. It operates from the onboard flash copy, with its own minimal
drivers.

Recovery capabilities:

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

### 4.1 Recovery Workflow

```text
SAGEBOOT
   ↓
Recovery
   ↓
mount SD → validate /system/kernel
   ↓
repair path (reinstall image, restore config, format)
   ↓
reboot
```

### 4.2 USB Mass Storage

During boot/recovery, SageBoot may optionally expose the SD card as a USB
Mass Storage device, giving a simple host-side development workflow:

```text
SAGEBOOT
   ↓
USB Mass Storage
   ↓
Host computer
   ↓
SageFS / FAT32
```

## 5. SageFS Mount and Kernel Loading

SageBoot mounts the filesystem read-only for the boot path:

```text
/                        (SageFS VFS root)
├── system/
│   ├── kernel           ← loaded by SageBoot
│   ├── boot             ← SageBoot configuration
│   └── config/          ← boot behavior, CPU mode, etc.
```

The kernel image is validated before execution (integrity check, size
limits, format check). A failed validation routes to Recovery Mode instead
of executing a corrupt kernel.

## 6. Architecture Detection

The RP2350 boot process selects the CPU architecture (ARM Cortex-M33 or
Hazard3 RISC-V). SageBoot:

1. Detects which architecture is running
2. Selects the matching Sage backend (`ARM-RP2350` or `RISCV-RP2350`)
3. Reports it in the boot screen and `arch` diagnostic

Both builds (`sagepocket-arm`, `sagepocket-rv`) share everything above this
layer — see [architecture.md](architecture.md) §4.

## 7. Watchdog and Crash Recovery

SageBoot records boot statistics to flash so the system can distinguish a
normal boot from a crash-induced reset:

```text
boot_count
crash_count
last_reset_reason
```

If an excessive crash count is detected, SageBoot automatically enters
Recovery Mode. See [security.md](security.md) for the crash-recovery
design.

## 8. Boot Performance Targets

```text
Boot to SageBoot:   < 1 second
Boot to SageOS:     < 3 seconds
Boot to GUI:        < 5 seconds
```

These are engineering targets, not guarantees.

## 9. Source Layout

```text
boot/
├── sageboot.sage       SageBoot entry and boot flow
├── startup/            Startup code (stack, CPU init, clocks)
├── linker/             Linker scripts (ARM and RISC-V)
└── recovery/           Recovery environment
```

## 10. Definition of Done (boot layer)

- [ ] Board powers on and executes SageBoot in < 1 s
- [ ] LCD displays boot information
- [ ] SD card is detected and mounted
- [ ] Kernel loads from `/system/kernel` and SageOS starts
- [ ] Boot menu, diagnostics, and recovery all functional
- [ ] Crash count / watchdog path routes to recovery

Related docs: [architecture.md](architecture.md), [hardware.md](hardware.md),
[sageos.md](sageos.md), [sagefs.md](sagefs.md), [development.md](development.md).