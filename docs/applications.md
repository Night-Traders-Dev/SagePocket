# SagePocket Applications and Packages

> **Version:** 0.1.0 · **Component:** apps/, packages/, emulators/ · **Related:** [architecture.md](architecture.md)

This document specifies SagePocket applications, the Sage Application
Package (`.sapp`) format, the application manager, retrocomputer emulators,
and the supporting asset formats and tools.

---

## 1. First-Party Applications

| App | Purpose | Source |
|-----|---------|--------|
| Terminal | SageShell with scrollback, history, ANSI colors, virtual terminals | `apps/terminal/` |
| Calculator | Integer, float, hex, binary, bitwise, scientific, programmer mode | `apps/calculator/` |
| File Manager | Browse, copy, move, rename, delete, launch apps, view text/images | `apps/fileman/` |
| Monitor | System diagnostics: CPU, memory, temperature, SD, tasks, FPS, VM | `apps/monitor/` |
| Paint | Bitmap editor: pencil, line, shapes, fill, text, color picker | `apps/paint/` |
| Settings | Brightness, rotation, clock, theme, boot, CPU mode, USB, power | `apps/settings/` |
| System | System info, diagnostics, logs, update | `apps/system/` |
| Games | Bundled games | `apps/games/` |

### 1.1 Monitor Example

```text
SAGE MONITOR

CPU       14%
TEMP      41.2 C
RAM       312 / 520 KB
SD        14.7 GB
TASKS     9
FPS       58
VM        RUNNING
USB       CONNECTED
```

### 1.2 Calculator Example

```text
0xFF + 1
```

Result: `256`

### 1.3 Paint

File format: `.simg`. Host tools convert PNG / BMP / JPEG.

## 2. Sage Application Package (.sapp)

```text
calculator.sapp
│
├── manifest
├── program.sbc
├── icon.sgi
├── assets/
└── libraries/
```

Manifest:

```text
name = Calculator
version = 1.0.0
entry = program.sbc
memory = 32K
permissions = display,filesystem
```

## 3. Application Manager

Commands:

```text
apps
install
uninstall
run
stop
info
update
```

Example:

```text
sage> apps

Calculator
File Manager
System Monitor
Paint
Terminal
Apple II
Sage BASIC
```

```text
sage> install calculator.sapp

Installing Calculator...
Extracting...
Registering...
Done.
```

Installed packages live under `/apps/` on SageFS and are launched by the
Application Manager through SageVM with the declared memory limit and
permissions (see [security.md](security.md)).

## 4. SageShell Command Reference

```text
help      list commands
ls        list directory
cd        change directory
pwd       print working directory
cat       print file
cp        copy file
mv        move/rename file
rm        remove file
mkdir     create directory
touch     create empty file

apps      list installed applications
install   install .sapp
uninstall remove application
run       launch application
stop      stop application

ps        list tasks
kill      terminate task
mem       memory statistics
cpu       CPU usage
temp      temperature
uptime    system uptime

mount     mount filesystem
umount    unmount filesystem
df        filesystem usage

clear     clear screen
reboot    reboot
shutdown  shut down

log       view logs (kernel, boot, sagevm, sagefs, gui)
system    system information
arch      architecture diagnostic
```

USB serial exposes the same shell as the LCD terminal:

```text
LCD terminal
      │
      ├── SageShell
      │
USB ──┘
```

## 5. USB Development Interface (sagectl)

Host tool `sagectl`:

```text
sagectl info
sagectl shell
sagectl upload
sagectl download
sagectl install
sagectl reboot
sagectl logs
sagectl monitor
sagectl flash
```

Example:

```text
sagectl upload calculator.sapp /apps/
```

During boot/recovery, USB Mass Storage mode exposes the SD card directly
(see [boot.md](boot.md) §4.2).

## 6. Developer Workflow

```text
write Sage code
      ↓
sagec
      ↓
Sage bytecode
      ↓
sagepack
      ↓
.sapp
      ↓
sagectl upload
      ↓
SagePocket
```

Host SDK tools:

```text
sagec        compile Sage → bytecode
sagelink     link bytecode modules
sagepack     pack .sapp
sageimg      image conversion (PNG/BMP/JPEG → .simg)
sagefont     font conversion (TTF → .sfont)
sagectl      device communication
mkfs.sage    filesystem image creation
```

System image tool: `sagepack-image` produces `sagepocket.img`
(boot + kernel + system files + default configuration).

## 7. Retrocomputer Layer

```text
SageOS
   ↓
SageVM
   ↓
Emulator
   ├── Sage6502
   ├── Apple II
   ├── Z80
   ├── Game Boy
   └── BASIC
```

| Emulator | Details |
|----------|---------|
| Sage6502 | Reusable 6502 core: A, X, Y, SP, PC, P; ADC/SBC/AND/ORA/EOR, LDA/LDX/LDY, STA/STX/STY, CMP/CPX/CPY, JMP/JSR/RTS, branches, PHA/PLA/PHP/PLP, TAX/TXA/TAY/TYA/TSX/TXS, INX/DEX/INY/DEY, ASL/LSR/ROL/ROR, CLC/SEC/CLI/SEI/CLV/CLD/SED, BRK/RTI/NOP |
| SageApple | Apple II-compatible: 6502, 64 KB memory, ROM, keyboard, text + graphics display, speaker, disk interface. ROMs from `/roms/apple2/`, run with `run apple2` |
| Z80 | Z80 CPU, memory, I/O, timers. Potential targets: CP/M, ZX Spectrum, MSX |
| Game Boy | Later: LR35902 CPU, PPU, memory, timer, joypad, cartridge, audio. ROMs from `/roms/gameboy/` |
| Sage BASIC | BASIC interpreter targeting SageVM (`10 PRINT "HELLO FROM SAGEPOCKET"` ...) |

### 7.1 Sage BASIC Pipeline

```text
BASIC
  ↓
BASIC parser
  ↓
Sage AST
  ↓
SageVM bytecode
  ↓
SageVM
```

### 7.2 ROM Storage

```text
/roms/apple2/
/roms/gameboy/
/roms/...
```

## 8. Asset Formats

```text
.simg    image
.sfont   font
.sicon   icon
.sanim   animation
```

Host conversions:

```text
PNG → .simg
TTF → .sfont
SVG → .simg
```

## 9. Definitions of Done

### SagePocket 0.4 (applications)

- [ ] `hello.sbc` runs on the board via SageVM
- [ ] Calculator, File Manager, Monitor, Terminal, Settings, Paint usable

### SagePocket 0.6 (package ecosystem)

- [ ] `.sapp` packages installable
- [ ] Application manager functional
- [ ] Permissions enforced per manifest

### SagePocket 0.9 (retrocomputing)

- [ ] Emulators execute from `/roms/`

Related docs: [sagevm.md](sagevm.md), [sageos.md](sageos.md),
[sagegui.md](sagegui.md), [security.md](security.md),
[development.md](development.md).