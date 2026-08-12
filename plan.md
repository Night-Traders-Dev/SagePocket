Below is a full project specification you can use as the master `plan.md`. I’ve structured it as an actual implementation roadmap rather than just a feature list.

The hardware baseline is the Waveshare **RP2350-LCD-1.47-A**: RP2350A, dual Cortex-M33 / dual Hazard3 architecture, 520 KB SRAM, 16 MB onboard NOR flash, 172×320 ST7789V3 SPI LCD, USB 1.1, TF/microSD, RGB LED, temperature sensor, and the RP2350 peripheral set. Waveshare also provides FAT32 TF-card and LCD examples, which makes those good bootstrap references rather than reinventing hardware initialization immediately. ([Waveshare][1])

# SagePocket

## A Complete SageLang-Based Microcomputer Platform

**Project:** SagePocket
**Target Hardware:** Waveshare RP2350-LCD-1.47-A
**Processor:** Raspberry Pi RP2350A
**Primary Language:** SageLang
**Operating System:** SageOS
**Bootloader:** SageBoot
**Virtual Machine:** SageVM
**Filesystem:** SageFS
**Display:** 172×320 ST7789V3 SPI LCD
**Persistent Storage:** 128 GB microSD / TF card
**Architectures:** ARM Cortex-M33 and Hazard3 RISC-V
**Status:** Architecture / Implementation Plan
**Version:** 0.1.0
**Date:** 2026

---

# 1. Project Vision

SagePocket is a complete miniature computer platform built around the Waveshare RP2350-LCD-1.47-A and implemented primarily in SageLang.

The goal is not merely to create a firmware demonstration.

The goal is to create a real, self-contained Sage computer with:

* a bootloader
* an operating system
* a filesystem
* a virtual machine
* a graphical user interface
* a command shell
* persistent storage
* applications
* games
* a package/application format
* hardware diagnostics
* a development environment
* multiple CPU architecture targets
* retrocomputer emulation
* a native Sage application ecosystem

The conceptual software stack is:

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

---

# 2. Hardware Platform

## 2.1 Target Board

The target is the Waveshare RP2350-LCD-1.47-A.

The board provides:

* RP2350A
* dual Cortex-M33 processor option
* dual Hazard3 RISC-V processor option
* up to 150 MHz operation
* 520 KB SRAM
* 16 MB W25Q128-series NOR flash
* 172×320 IPS LCD
* ST7789V3 display controller
* SPI display interface
* TF/microSD slot
* USB 1.1
* USB device support
* USB host support
* RGB LED
* hardware reset
* temperature sensor
* GPIO
* SPI
* I²C
* UART
* PWM
* ADC
* PIO

The RP2350 itself provides 520 KB of SRAM, 2 SPI controllers, 2 I²C controllers, 2 UARTs, 24 PWM channels, USB 1.1, 12 PIO state machines and other peripherals. ([Raspberry Pi][2])

## 2.2 Display

Display:

```text
Controller: ST7789V3
Resolution: 172 × 320
Interface: 4-wire SPI
Color: RGB565 initially
```

The display will become the primary graphical interface for SageOS.

Waveshare documents RGB565 operation and provides both low-level LCD and LVGL examples. ([Waveshare][3])

## 2.3 Storage

Primary removable storage:

```text
128 GB microSD / TF
```

Bootstrap filesystem:

```text
FAT32
```

Long-term filesystem:

```text
SageFS
```

The initial system will use FAT32 compatibility because the board's official TF-card demonstration uses FAT32. ([Waveshare][1])

---

# 3. Core Design Principles

SagePocket should follow these principles.

## 3.1 Sage-first

SageLang should be the primary implementation language.

C/C++ should initially be restricted to:

* hardware bootstrap
* vendor SDK integration
* unavoidable ROM/startup requirements
* reference implementations
* debugging

The long-term objective is:

```text
SageBoot       → Sage
SageOS         → Sage
SageFS         → Sage
SageVM         → Sage
SageGUI        → Sage
Applications   → Sage
Tools          → Sage
```

## 3.2 Small-core architecture

Do not attempt to reproduce Linux.

SageOS should be:

```text
small
deterministic
modular
embedded
inspectable
portable
```

## 3.3 Architecture neutrality

SageVM should allow the same application bytecode to execute on:

```text
RP2350 ARM
RP2350 RISC-V
Linux
Android
Windows
macOS
Sage emulator
```

where supported.

## 3.4 Persistent-by-default

Applications and user data should live on SageFS rather than consuming scarce onboard flash.

## 3.5 Hardware abstraction

Applications should not directly manipulate RP2350 registers.

Instead:

```text
Application
    ↓
SageOS API
    ↓
Sage device subsystem
    ↓
RP2350 driver
    ↓
Hardware
```

---

# 4. Repository Structure

Recommended repository:

```text
SagePocket/
│
├── README.md
├── LICENSE
├── plan.md
├── CHANGELOG.md
├── UPDATES.md
│
├── docs/
│   ├── architecture.md
│   ├── hardware.md
│   ├── boot.md
│   ├── sageos.md
│   ├── sagefs.md
│   ├── sagevm.md
│   ├── sagegui.md
│   ├── drivers.md
│   ├── applications.md
│   ├── security.md
│   └── development.md
│
├── boot/
│   ├── sageboot.sage
│   ├── startup/
│   ├── linker/
│   └── recovery/
│
├── kernel/
│   ├── kernel.sage
│   ├── scheduler.sage
│   ├── memory.sage
│   ├── process.sage
│   ├── ipc.sage
│   ├── interrupt.sage
│   ├── timer.sage
│   └── syscall.sage
│
├── drivers/
│   ├── lcd/
│   │   └── st7789v3.sage
│   ├── sd/
│   │   └── sd_spi.sage
│   ├── usb/
│   ├── gpio/
│   ├── uart/
│   ├── spi/
│   ├── i2c/
│   ├── pwm/
│   ├── adc/
│   ├── pio/
│   ├── rgb/
│   └── temperature/
│
├── sagefs/
│   ├── vfs.sage
│   ├── fat32.sage
│   ├── inode.sage
│   ├── block.sage
│   ├── cache.sage
│   ├── journal.sage
│   └── sagefs.sage
│
├── sagevm/
│   ├── vm.sage
│   ├── bytecode.sage
│   ├── interpreter.sage
│   ├── memory.sage
│   ├── gc.sage
│   ├── syscall.sage
│   ├── loader.sage
│   └── jit/
│
├── gui/
│   ├── framebuffer.sage
│   ├── graphics.sage
│   ├── font.sage
│   ├── widgets.sage
│   ├── window.sage
│   ├── menu.sage
│   ├── shell_ui.sage
│   └── desktop.sage
│
├── shell/
│   ├── shell.sage
│   ├── commands/
│   └── parser.sage
│
├── apps/
│   ├── terminal/
│   ├── calculator/
│   ├── fileman/
│   ├── monitor/
│   ├── paint/
│   ├── settings/
│   ├── system/
│   └── games/
│
├── emulators/
│   ├── sage6502/
│   ├── apple2/
│   ├── z80/
│   ├── gameboy/
│   └── basic/
│
├── packages/
│   ├── format/
│   ├── installer/
│   └── repository/
│
├── tools/
│   ├── image2sage/
│   ├── font2sage/
│   ├── mkfs.sage/
│   ├── mkapp.sage/
│   ├── pack.sage/
│   ├── flash.sage/
│   └── monitor.sage
│
├── tests/
│   ├── unit/
│   ├── hardware/
│   ├── sagefs/
│   ├── sagevm/
│   ├── gui/
│   └── integration/
│
├── examples/
│   ├── hello.sage
│   ├── lcd.sage
│   ├── sd.sage
│   ├── gui.sage
│   └── app.sage
│
└── assets/
    ├── fonts/
    ├── icons/
    ├── themes/
    └── boot/
```

---

# 5. System Architecture

SagePocket consists of seven major layers.

```text
Layer 7     Applications
               │
Layer 6     SageGUI / SageShell
               │
Layer 5     SageVM
               │
Layer 4     SageOS
               │
Layer 3     SageFS
               │
Layer 2     Drivers / HAL
               │
Layer 1     SageBoot / Hardware
```

---

# 6. SageBoot

## 6.1 Purpose

SageBoot is the first Sage-controlled software layer after the RP2350 boot ROM.

Responsibilities:

1. initialize execution environment
2. initialize clocks
3. establish memory
4. identify CPU architecture
5. initialize basic peripherals
6. initialize display
7. detect SD card
8. locate SageOS
9. validate SageOS
10. load SageOS
11. transfer control to SageOS

## 6.2 Boot Flow

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

## 6.3 Boot Menu

If a boot key or recovery condition is detected:

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

## 6.4 Recovery Mode

Recovery must remain functional even if SageOS is corrupted.

Recovery functions:

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

---

# 7. Dual-Architecture Strategy

The RP2350 uniquely provides a choice between dual Cortex-M33 and dual Hazard3 RISC-V processors. Raspberry Pi documents architecture switching through the boot process. ([Raspberry Pi][4])

SagePocket should therefore support two official builds.

```text
sagepocket-arm
sagepocket-rv
```

## 7.1 ARM Build

Target:

```text
ARM Cortex-M33
```

Advantages:

* mature toolchain
* hardware floating point
* DSP instructions
* broad ecosystem

## 7.2 RISC-V Build

Target:

```text
Hazard3 RISC-V
```

Advantages:

* open ISA
* Sage RISC-V backend testing
* direct integration with existing Sage RISC-V work
* architecture experimentation

## 7.3 Shared Architecture

Both targets must share:

```text
SageOS API
SageFS
SageVM bytecode
SageGUI
applications
shell
configuration
```

Only the lowest-level architecture-dependent layer should differ.

---

# 8. Hardware Abstraction Layer

Create:

```text
SageHAL
```

API:

```text
hal.cpu()
hal.memory()
hal.gpio()
hal.spi()
hal.i2c()
hal.uart()
hal.pwm()
hal.adc()
hal.timer()
hal.usb()
hal.pio()
hal.temperature()
```

Applications should never directly depend on RP2350 register definitions.

Example conceptual API:

```text
lcd.init()
lcd.clear()
lcd.pixel(x, y, color)
lcd.rectangle(...)
lcd.text(...)
lcd.flush()
```

rather than:

```text
RP2350.SPI0.CS = ...
```

---

# 9. LCD Driver

Implement:

```text
drivers/lcd/st7789v3.sage
```

## 9.1 Required Functions

```text
lcd_init()
lcd_reset()
lcd_set_rotation()
lcd_set_window()
lcd_write_command()
lcd_write_data()
lcd_set_backlight()
lcd_pixel()
lcd_fill()
lcd_blit()
lcd_flush()
```

## 9.2 Framebuffer

Initial format:

```text
RGB565
```

Full framebuffer size:

```text
172 × 320 × 2
= 110,080 bytes
≈ 107.5 KiB
```

Because this consumes a significant portion of SRAM, SageGUI should support partial/tiled rendering.

Recommended:

```text
full framebuffer       optional
1/3 framebuffer        default GUI mode
small dirty rectangles low-memory mode
```

Waveshare's LVGL documentation specifically demonstrates partial rendering and fractional draw buffers, supporting this strategy. ([Waveshare][1])

---

# 10. Graphics Engine

Create:

```text
SageGraphics
```

Functions:

```text
pixel()
line()
rectangle()
fill_rectangle()
circle()
triangle()
bitmap()
sprite()
text()
image()
scroll()
```

Support:

```text
RGB565
1-bit bitmap
4-bit indexed bitmap
8-bit indexed bitmap
```

Later:

```text
alpha blending
sprites
clipping
dirty rectangles
hardware-assisted transfers
DMA
```

---

# 11. SageGUI

SageGUI is the native graphical environment.

## 11.1 Components

```text
Window
Panel
Button
Label
TextBox
List
Menu
Dialog
Slider
ProgressBar
Icon
Canvas
StatusBar
Terminal
```

## 11.2 Desktop

Default screen:

```text
┌─────────────────────────────┐
│ SAGEOS              19:35   │
├─────────────────────────────┤
│                             │
│  [ Terminal ]  [ Files ]    │
│                             │
│  [ Monitor  ]  [ Apps  ]    │
│                             │
│  [ Games    ]  [ Settings ] │
│                             │
│                             │
│                             │
├─────────────────────────────┤
│ CPU  12%  MEM 84K  SD 2GB   │
└─────────────────────────────┘
```

## 11.3 GUI API

Applications should be able to do:

```text
window = gui.window("Calculator")

button = window.button("7")
button.on_click(...)
```

The API should compile to SageVM operations.

---

# 12. SageOS Kernel

SageOS should initially be a cooperative/preemptive hybrid embedded kernel.

## 12.1 Kernel Components

```text
scheduler
task manager
interrupt manager
memory manager
IPC
timers
device manager
VFS
process manager
system calls
power manager
```

## 12.2 Task Model

Initial:

```text
kernel task
idle task
GUI task
VM task
filesystem task
USB task
shell task
```

Later applications become independent processes/tasks.

---

# 13. Scheduler

Initial scheduler:

```text
priority-based round robin
```

Task states:

```text
READY
RUNNING
BLOCKED
SLEEPING
TERMINATED
```

Example:

```text
Task                 Priority

kernel               255
filesystem            200
USB                    180
GUI                    150
VM                     120
shell                  100
background              50
idle                     0
```

The exact values are implementation details and should remain configurable.

---

# 14. Memory Management

The RP2350 provides 520 KB SRAM. ([Raspberry Pi][2])

Memory must therefore be carefully partitioned.

Initial conceptual layout:

```text
520 KB SRAM
│
├── Kernel
├── Kernel heap
├── Task stacks
├── SageVM
├── GUI buffers
├── filesystem cache
├── DMA buffers
└── application memory
```

Implement:

```text
physical allocator
kernel heap
application heap
stack allocator
shared memory
memory statistics
```

Provide:

```text
sage> mem
```

Output:

```text
SRAM

Total:       520 KB
Kernel:       72 KB
VM:           96 KB
GUI:          64 KB
Filesystem:   32 KB
Applications: 48 KB
Free:        208 KB
```

---

# 15. Multicore Architecture

The RP2350 provides two cores in the selected architecture. ([Raspberry Pi][2])

SagePocket should initially use one core.

Once stable:

```text
CORE 0
SageOS kernel
filesystem
interrupts

CORE 1
SageVM
GUI
applications
```

Later implement optional affinity:

```text
task.cpu = 0
task.cpu = 1
task.cpu = any
```

## 15.1 Multicore IPC

Implement:

```text
mailboxes
queues
shared memory
events
spinlocks
mutexes
semaphores
```

---

# 16. SageFS

SageFS is the persistent storage layer.

## 16.1 Architecture

```text
Application
    ↓
SageFS API
    ↓
VFS
    ↓
Filesystem driver
    ↓
Block device
    ↓
SD SPI
    ↓
microSD
```

## 16.2 Bootstrap

Use:

```text
FAT32
```

Initially SageOS mounts:

```text
/sd
```

Then provides:

```text
/
```

through the SageFS VFS.

## 16.3 Native SageFS

Later implement:

```text
SageFS
```

with:

* native metadata
* allocation tables
* directories
* file extents
* journaling
* crash recovery
* integrity checking
* caching
* wear-aware allocation
* checksums

---

# 17. SageFS Directory Layout

```text
/
├── system/
│   ├── kernel
│   ├── boot
│   ├── config/
│   ├── drivers/
│   └── libraries/
│
├── bin/
│
├── apps/
│
├── lib/
│
├── home/
│   └── user/
│
├── data/
│
├── games/
│
├── roms/
│
├── tmp/
│
├── logs/
│
├── cache/
│
└── recovery/
```

---

# 18. SageFS API

Implement:

```text
fs.open()
fs.close()
fs.read()
fs.write()
fs.seek()
fs.stat()
fs.mkdir()
fs.remove()
fs.rename()
fs.list()
fs.mount()
fs.unmount()
fs.sync()
```

CLI:

```text
ls
cd
pwd
cat
cp
mv
rm
mkdir
touch
df
mount
umount
```

---

# 19. SD Driver

Implement:

```text
SPI initialization
card detection
card initialization
block read
block write
sector addressing
capacity detection
error handling
timeouts
```

Then expose:

```text
block_device.read_sector()
block_device.write_sector()
```

The filesystem should not know that the storage is an SD card.

---

# 20. SageVM

SageVM is the portable execution layer.

## 20.1 Pipeline

```text
SageLang
   ↓
Lexer
   ↓
Parser
   ↓
AST
   ↓
Compiler
   ↓
Sage Bytecode
   ↓
SageVM
```

## 20.2 VM Components

```text
bytecode loader
instruction decoder
registers
stack
heap
call stack
GC
syscalls
module loader
exception handling
debugger
```

## 20.3 Bytecode

Initial instruction categories:

```text
LOAD
STORE
MOVE

ADD
SUB
MUL
DIV
MOD

AND
OR
XOR
NOT
SHL
SHR

CMP
JMP
JZ
JNZ

CALL
RET

PUSH
POP

ALLOC
FREE

LOAD_GLOBAL
STORE_GLOBAL

SYSCALL

HALT
```

---

# 21. SageVM Memory Model

Conceptual:

```text
VM
│
├── bytecode
├── constant pool
├── registers
├── operand stack
├── call stack
├── heap
└── globals
```

VM applications should have a configurable memory limit.

Example:

```text
run calculator --memory=32K
```

---

# 22. SageVM System Calls

Applications communicate with SageOS through VM syscalls.

Examples:

```text
SYS_EXIT
SYS_OPEN
SYS_READ
SYS_WRITE
SYS_CLOSE

SYS_SLEEP
SYS_TIME

SYS_DISPLAY
SYS_INPUT

SYS_FS_STAT
SYS_FS_LIST

SYS_THREAD_CREATE

SYS_RANDOM

SYS_SYSTEM_INFO
```

---

# 23. Sage Application Format

Define:

```text
.sapp
```

Sage Application Package.

Structure:

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

---

# 24. Application Manager

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

Install:

```text
sage> install calculator.sapp

Installing Calculator...
Extracting...
Registering...
Done.
```

---

# 25. SageShell

Text interface:

```text
sage>
```

Required commands:

```text
help
ls
cd
pwd
cat
cp
mv
rm
mkdir
touch

apps
install
uninstall
run
stop

ps
kill
mem
cpu
temp
uptime

mount
umount
df

clear
reboot
shutdown
```

---

# 26. SageTerminal

The terminal application should support:

```text
command history
cursor navigation
scrollback
basic ANSI escape sequences
colored text
multiple virtual terminals
```

USB serial should expose the same shell.

Therefore:

```text
LCD terminal
      │
      ├── SageShell
      │
USB ──┘
```

---

# 27. SageMonitor

Create a system diagnostics application.

Display:

```text
CPU
MEMORY
TEMPERATURE
SD
TASKS
INTERRUPTS
FPS
VM
USB
```

Example:

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

---

# 28. File Manager

SageFileman provides graphical filesystem access.

Features:

```text
browse
open
copy
move
rename
delete
create folder
file information
launch .sapp
launch .sage
view text
view images
```

---

# 29. SagePaint

A simple bitmap editor.

Features:

```text
pixel
pencil
line
rectangle
circle
fill
text
color picker
save
load
```

File format:

```text
.simg
```

Support conversion from:

```text
PNG
BMP
JPEG
```

on host systems.

---

# 30. Sage Calculator

Native Sage application.

Operations:

```text
integer
floating point
hexadecimal
binary
bitwise
scientific
programmer mode
```

Example:

```text
0xFF + 1
```

Result:

```text
256
```

---

# 31. Sage Settings

Configure:

```text
brightness
rotation
clock
theme
boot behavior
CPU mode
filesystem
USB mode
power management
```

---

# 32. Sage BASIC

Implement a BASIC interpreter targeting SageVM.

Example:

```text
10 PRINT "HELLO FROM SAGEPOCKET"
20 FOR I = 1 TO 10
30 PRINT I
40 NEXT I
```

Pipeline:

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

---

# 33. Retrocomputer Layer

SagePocket should eventually host virtual machines.

Architecture:

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

This connects SagePocket to the existing Sage6502 / SageApple work.

---

# 34. Sage6502

Implement a reusable 6502 core.

Components:

```text
A
X
Y
SP
PC
P
```

Implement:

```text
ADC
SBC
AND
ORA
EOR

LDA
LDX
LDY

STA
STX
STY

CMP
CPX
CPY

JMP
JSR
RTS

BCC
BCS
BEQ
BNE
BMI
BPL
BVC
BVS

PHA
PLA
PHP
PLP

TAX
TXA
TAY
TYA
TSX
TXS

INX
DEX
INY
DEY

ASL
LSR
ROL
ROR

CLC
SEC
CLI
SEI
CLV
CLD
SED

BRK
RTI
NOP
```

---

# 35. SageApple

Create an Apple II-compatible environment:

```text
6502 CPU
64 KB memory
ROM
keyboard
text display
graphics
speaker
disk interface
```

Storage:

```text
/roms/apple2/
```

Run:

```text
sage> run apple2
```

---

# 36. Game Boy Emulator

Later implement:

```text
Sharp LR35902 CPU
PPU
memory
timer
joypad
cartridge
audio
```

ROM storage:

```text
/roms/gameboy/
```

The emulator should use SageVM/native Sage code where performance permits.

---

# 37. Z80 Emulator

Provide:

```text
Z80 CPU
memory
I/O
timers
```

Potential targets:

```text
CP/M
ZX Spectrum
MSX
```

---

# 38. Graphics Assets

Create Sage-native asset formats.

```text
.simg    image
.sfont   font
.sicon   icon
.sanim   animation
```

Host tools convert common formats:

```text
PNG → .simg
TTF → .sfont
SVG → .simg
```

---

# 39. USB Development Interface

SagePocket should expose a USB development protocol.

Host:

```text
sagectl
```

Commands:

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

---

# 40. USB Mass Storage

During boot/recovery, optionally expose a mass-storage interface.

Possible modes:

```text
SAGEBOOT
   ↓
USB Mass Storage
   ↓
Host computer
   ↓
SageFS / FAT32
```

This provides a simple development workflow.

---

# 41. Host Development Kit

Create:

```text
SagePocket SDK
```

Tools:

```text
sagec
sagelink
sagepack
sageimg
sagefont
sagectl
mkfs.sage
```

Typical workflow:

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

---

# 42. Native Sage Compilation

After the VM is stable, support native compilation.

Pipeline:

```text
SageLang
    ↓
Sage IR
    ↓
ARM backend
    ↓
RP2350 machine code
```

and:

```text
SageLang
    ↓
Sage IR
    ↓
RISC-V backend
    ↓
Hazard3 machine code
```

The same source should therefore support:

```text
Sage → ARM
Sage → RISC-V
Sage → SageVM
```

---

# 43. JIT Strategy

A full JIT should not be an early requirement.

Implement in stages:

```text
Stage 1
bytecode interpreter

Stage 2
bytecode optimizer

Stage 3
hot-block detection

Stage 4
native code cache

Stage 5
ARM JIT

Stage 6
RISC-V JIT
```

Native code should only consume RAM when worthwhile.

---

# 44. Security Model

SagePocket should eventually support application permissions.

Example:

```text
permissions =
    display
    filesystem
    usb
    network
    hardware
```

An application requesting:

```text
hardware
```

could require user confirmation.

Example:

```text
Calculator requests:

[ ] Filesystem
[✓] Display

Allow?
YES / NO
```

---

# 45. Application Sandboxing

SageVM applications should initially be sandboxed.

Application receives:

```text
virtual memory
virtual filesystem namespace
system-call interface
```

Instead of unrestricted hardware access.

Example:

```text
/apps/calculator/
```

cannot automatically modify:

```text
/system/
```

---

# 46. Logging

Implement:

```text
/logs/kernel.log
/logs/boot.log
/logs/sagevm.log
/logs/sagefs.log
/logs/gui.log
```

Commands:

```text
log
log kernel
log boot
log clear
```

---

# 47. Crash Recovery

If an application crashes:

```text
Application fault
      ↓
SageVM detects fault
      ↓
terminate application
      ↓
release memory
      ↓
write crash log
      ↓
return to desktop
```

Kernel faults should enter:

```text
SAGEOS KERNEL PANIC
```

with:

```text
PC
SP
registers
task
fault code
stack trace
```

---

# 48. Watchdog

Implement a watchdog service.

The kernel periodically feeds the watchdog.

If the system becomes unresponsive:

```text
watchdog
    ↓
reset
    ↓
SageBoot
    ↓
crash recovery
```

Boot counter:

```text
boot_count
crash_count
last_reset_reason
```

---

# 49. Power Management

Implement:

```text
active
idle
sleep
dormant
```

Services should be able to request:

```text
power.keep_awake()
power.allow_sleep()
```

Display backlight should be independently controlled.

---

# 50. Clock and Timer Subsystem

Expose:

```text
time.now()
timer.create()
timer.sleep()
timer.periodic()
```

System utilities:

```text
date
time
uptime
```

---

# 51. Hardware Diagnostics

Create a boot diagnostic suite.

Tests:

```text
CPU
SRAM
FLASH
LCD
SD
RGB
GPIO
SPI
I2C
UART
USB
ADC
temperature
timer
PIO
```

Example:

```text
SAGE HARDWARE DIAGNOSTICS

CPU ............. PASS
SRAM ............ PASS
FLASH ........... PASS
LCD ............. PASS
SD .............. PASS
RGB ............. PASS
USB ............. PASS
TEMP ............ PASS

ALL TESTS PASSED
```

---

# 52. SD Card Diagnostics

Because the SD card is critical, provide:

```text
sdinfo
sdtest
sdspeed
sdfmt
```

Example:

```text
SD CARD

Capacity: 128 GB
Filesystem: FAT32
Sector size: 512
Read: 18.2 MB/s
Write: 11.7 MB/s
Status: GOOD
```

Actual speeds should be measured rather than assumed.

---

# 53. SageFS Formatting Tool

Host tool:

```text
mkfs.sage
```

Device command:

```text
sdfmt
```

Stages:

```text
FAT32 compatibility
       ↓
SageFS metadata
       ↓
SageFS native format
```

Do not destroy user data without explicit confirmation.

---

# 54. Development Phases

## Phase 0 — Repository

Deliver:

```text
repository
build system
documentation
hardware definitions
test framework
```

Exit criteria:

```text
clean repository builds
```

---

## Phase 1 — Hardware Bring-Up

Implement:

```text
startup
GPIO
clock
UART
LED
temperature
```

Exit criteria:

```text
RP2350 executes Sage-controlled firmware.
```

---

## Phase 2 — LCD

Implement:

```text
ST7789V3
SPI
framebuffer
text
graphics primitives
```

Exit criteria:

```text
SageBoot displays diagnostics.
```

---

## Phase 3 — SD

Implement:

```text
SPI SD
block device
FAT32
file read
file write
directory enumeration
```

Exit criteria:

```text
sage> ls
```

works from the physical SD card.

---

## Phase 4 — SageBoot

Implement:

```text
boot menu
kernel loader
recovery
diagnostics
```

Exit criteria:

```text
SageBoot loads SageOS from storage.
```

---

## Phase 5 — SageOS Kernel

Implement:

```text
scheduler
tasks
interrupts
memory
timers
IPC
```

Exit criteria:

```text
multiple SageOS tasks run simultaneously.
```

---

## Phase 6 — SageFS

Implement:

```text
VFS
FAT32 backend
cache
file descriptors
directories
```

Exit criteria:

```text
SageOS has a persistent filesystem.
```

---

## Phase 7 — SageShell

Implement:

```text
terminal
commands
USB console
```

Exit criteria:

```text
sage>
```

works locally and over USB.

---

## Phase 8 — SageVM

Implement:

```text
bytecode
interpreter
loader
memory
syscalls
```

Exit criteria:

```text
hello.sbc
```

runs on the board.

---

## Phase 9 — Sage Applications

Build:

```text
Calculator
File Manager
Monitor
Terminal
Settings
Paint
```

Exit criteria:

```text
SagePocket is usable without a host computer.
```

---

## Phase 10 — SageGUI

Implement:

```text
desktop
windows
widgets
menus
icons
touch/input abstraction if available
```

Exit criteria:

```text
SagePocket boots directly into a graphical desktop.
```

---

## Phase 11 — Application Packages

Implement:

```text
.sapp
manifest
installer
application manager
permissions
```

Exit criteria:

```text
third-party Sage applications can be installed.
```

---

## Phase 12 — Multicore

Implement:

```text
core management
IPC
affinity
parallel tasks
```

Exit criteria:

```text
SageOS successfully distributes work across both cores.
```

---

## Phase 13 — RISC-V

Port:

```text
SageBoot
HAL
kernel
drivers
```

to Hazard3.

Exit criteria:

```text
SagePocket ARM and SagePocket RISC-V builds run the same Sage applications.
```

---

## Phase 14 — Retrocomputing

Implement:

```text
Sage6502
SageApple
Z80
Game Boy
Sage BASIC
```

Exit criteria:

```text
retrocomputing applications execute from /roms/.
```

---

## Phase 15 — Native Compilation

Implement:

```text
ARM backend
RISC-V backend
native system applications
```

Exit criteria:

```text
Sage applications can run without the VM when compiled natively.
```

---

## Phase 16 — Native SageFS

Replace:

```text
FAT32
```

with:

```text
SageFS
```

while retaining FAT32 import/export compatibility.

Exit criteria:

```text
SageFS survives power-loss testing and filesystem corruption tests.
```

---

# 55. Version Roadmap

## SagePocket 0.1

Hardware bring-up.

```text
SageBoot
LCD
SD
LED
UART
```

## SagePocket 0.2

Kernel.

```text
scheduler
memory
tasks
timers
```

## SagePocket 0.3

Filesystem.

```text
SageFS/VFS
FAT32
shell
```

## SagePocket 0.4

VM.

```text
SageVM
bytecode
applications
```

## SagePocket 0.5

GUI.

```text
SageGUI
desktop
file manager
```

## SagePocket 0.6

Application ecosystem.

```text
.sapp
installer
package manager
```

## SagePocket 0.7

Multicore.

```text
SMP
IPC
task affinity
```

## SagePocket 0.8

RISC-V.

```text
Hazard3
RISC-V SageBoot
RISC-V SageOS
```

## SagePocket 0.9

Retrocomputing.

```text
Sage6502
SageApple
Z80
Game Boy
```

## SagePocket 1.0

Complete platform.

```text
SageBoot
SageOS
SageFS
SageVM
SageGUI
SageLang
ARM
RISC-V
Applications
Package system
Recovery
Diagnostics
```

---

# 56. Performance Targets

Initial targets:

```text
Boot to SageBoot:
< 1 second

Boot to SageOS:
< 3 seconds

Boot to GUI:
< 5 seconds

Shell response:
< 50 ms

GUI target:
30+ FPS

Filesystem:
stable before fast

VM:
correctness before performance
```

The numbers are engineering targets, not guarantees.

---

# 57. Resource Budgets

Initial target:

```text
SRAM
────────────────────────────

Kernel                 64 KB
SageVM                  96 KB
GUI                     80 KB
Filesystem              32 KB
Drivers                 32 KB
Tasks                   64 KB
Buffers                 32 KB
Free                    120 KB
```

This budget must be validated experimentally.

The full framebuffer should not be permanently allocated unless the memory profile proves it worthwhile.

---

# 58. Flash Layout

The board has 16 MB of onboard NOR flash. ([Waveshare][5])

Initial conceptual layout:

```text
0x000000
│
├── SageBoot
├── recovery
├── kernel
├── hardware configuration
├── minimal libraries
└── reserved
```

SD contains:

```text
applications
user data
ROMs
assets
logs
cache
large libraries
```

---

# 59. System Image

Define:

```text
sagepocket.img
```

Containing:

```text
boot
kernel
system files
default configuration
filesystem metadata
```

Host tool:

```text
sagepack-image
```

---

# 60. Developer Workflow

## Host

```text
SageLang source
       ↓
Sage compiler
       ↓
SageVM bytecode
       ↓
.sapp
       ↓
sagectl
       ↓
USB
       ↓
SagePocket
```

## Device

```text
USB
 ↓
SageBoot / SageOS
 ↓
SageFS
 ↓
Application Manager
 ↓
SageVM
 ↓
Application
```

---

# 61. Testing Strategy

## Unit Tests

Test:

```text
parser
bytecode
VM
filesystem
graphics
memory
scheduler
```

## Hardware Tests

Test:

```text
LCD
SD
SPI
USB
GPIO
temperature
RGB
```

## Integration Tests

Test:

```text
boot → filesystem
filesystem → VM
VM → GUI
GUI → applications
USB → shell
```

## Stress Tests

Run:

```text
filesystem write/read loops
VM allocation loops
task creation loops
GUI rendering loops
multicore stress
SD power-loss simulation
```

---

# 62. Fault Injection

Deliberately test:

```text
corrupt kernel
corrupt application
corrupt filesystem metadata
remove SD during read
remove SD during write
VM out-of-memory
invalid bytecode
stack overflow
heap exhaustion
task deadlock
watchdog timeout
```

The system should recover whenever possible.

---

# 63. Documentation

Required documentation:

```text
SagePocket Architecture
SageBoot Specification
SageOS Kernel API
SageFS Specification
SageVM Bytecode Specification
SageGUI API
Sage Application Specification
Sage Device Driver API
SagePocket Hardware Reference
SagePocket Developer Guide
SagePocket User Guide
```

---

# 64. Example Sage Application

Conceptual:

```text
app "Hello"

    window = gui.window("Hello")

    window.label(
        "Hello from SagePocket!"
    )

    window.button(
        "OK"
    )

    window.show()
```

The exact syntax must follow the current SageLang specification rather than inventing syntax here.

---

# 65. SagePocket System Information

Implement:

```text
sage> system
```

Example:

```text
SAGEPOCKET

OS:        SageOS 0.5
Boot:      SageBoot 0.4
VM:        SageVM 0.4
FS:        SageFS 0.3

CPU:       RP2350A
ARCH:      ARM Cortex-M33
CLOCK:     150 MHz

SRAM:      520 KB
FLASH:     16 MB

LCD:       ST7789V3
DISPLAY:   172x320

SD:        128 GB
USB:       1.1

UPTIME:    00:12:42
```

---

# 66. Architecture Diagnostic

Provide:

```text
sage> arch
```

Output:

```text
RP2350

Available architectures:

[1] ARM Cortex-M33
[2] Hazard3 RISC-V

Current:
ARM Cortex-M33

Sage backend:
ARM-RP2350

VM:
SageVM-32
```

---

# 67. Future Network Expansion

Do not make networking a requirement for v1.

However, design SageOS so networking can eventually be added.

Possible future hardware:

```text
ESP32
Ethernet
Wi-Fi
USB network adapter
```

Sage networking stack:

```text
SageNet
 ├── sockets
 ├── TCP
 ├── UDP
 ├── DNS
 ├── HTTP
 └── SageRPC
```

---

# 68. SageRPC

Eventually allow a SagePocket device to communicate with:

```text
SagePhone
SagePC
Orange Pi
SageVM
another SagePocket
```

Potential architecture:

```text
SagePocket
     │
     │ SageRPC
     ▼
Sage computer
```

This can eventually become part of the larger Sage ecosystem.

---

# 69. Distributed SageFS

The long-term SageFS architecture could support remote storage:

```text
Local SageFS
      │
      ├── local
      ├── removable
      └── remote
```

Example:

```text
/home/user
```

could theoretically be backed by:

```text
SD
NAS
SageFS node
SageCloud
```

This should remain a future feature and not complicate the initial embedded filesystem.

---

# 70. SagePocket as a Sage Development Target

The project should become a permanent target platform for SageLang.

Compiler target:

```text
sagepocket-arm
sagepocket-riscv
sagepocket-vm
```

Runtime target:

```text
SageVM-RP2350
```

OS target:

```text
SageOS-RP2350
```

This allows SageLang itself to be developed against real hardware.

---

# 71. Definition of Done

SagePocket 1.0 is complete when the board can:

```text
✓ Power on
✓ Execute SageBoot
✓ Detect RP2350 hardware
✓ Display boot information
✓ Mount the SD card
✓ Start SageOS
✓ Run multiple tasks
✓ Manage memory
✓ Execute SageVM bytecode
✓ Run Sage applications
✓ Display a graphical desktop
✓ Open a terminal
✓ Browse files
✓ Install applications
✓ Store persistent user data
✓ Communicate through USB
✓ Recover from application crashes
✓ Enter recovery mode
✓ Run diagnostics
✓ Execute Sage BASIC
✓ Run Sage6502
✓ Run SageApple
✓ Support ARM
✓ Support Hazard3 RISC-V
✓ Compile Sage applications
✓ Run applications from SageFS
```

---

# 72. Final Architecture

The finished SagePocket platform should look like this:

```text
                         SAGEPOCKET
                              │
                ┌─────────────┴─────────────┐
                │                           │
            SageBoot                    Recovery
                │
                ▼
             SageOS
                │
     ┌──────────┼───────────┐
     │          │           │
  SageFS     SageVM     SageGUI
     │          │           │
     │          │      ┌────┼────┐
     │          │      │    │    │
     │          │   Desktop Apps Shell
     │          │
     │      ┌───┼───────────────┐
     │      │   │       │       │
     │   SageLang BASIC 6502   Z80
     │      │   │       │       │
     └──────┴───┴───────┴───────┘
                │
                ▼
             SageHAL
                │
        ┌───────┼────────┐
        │       │        │
       LCD      SD      USB
        │       │        │
        └───────┼────────┘
                │
             RP2350A
        ┌───────┴────────┐
        │                │
   Cortex-M33         Hazard3
     ARM               RISC-V
        │                │
        └───────┬────────┘
                │
             Hardware
```

---

# 73. Immediate Implementation Order

Do **not** attempt to implement everything simultaneously.

The recommended actual development order is:

```text
01. Create SagePocket repository
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
22. Run first `.sbc`
23. Implement system calls
24. Implement SageGUI
25. Build desktop
26. Build Calculator
27. Build File Manager
28. Build Monitor
29. Build Settings
30. Implement `.sapp`
31. Implement application manager
32. Implement USB `sagectl`
33. Implement multicore support
34. Port SageBoot to Hazard3
35. Port SageOS to Hazard3
36. Run identical SageVM applications on both
37. Implement Sage6502
38. Implement SageApple
39. Implement Sage BASIC
40. Implement Z80
41. Implement Game Boy
42. Implement native ARM compiler backend
43. Implement native RISC-V backend
44. Implement native SageFS
45. Implement filesystem journaling
46. Implement crash recovery
47. Implement security/sandboxing
48. Optimize VM
49. Optimize GUI
50. Release SagePocket 1.0
```

---

# 74. Long-Term Goal

SagePocket should ultimately demonstrate that SageLang can be used to construct an entire computing environment rather than simply applications.

The complete stack becomes:

```text
               SAGE LANGUAGE
                    │
                    ▼
             Sage Compiler
                    │
          ┌─────────┴─────────┐
          │                   │
       Native              SageVM
          │                   │
          └─────────┬─────────┘
                    ▼
                 SageOS
                    │
       ┌────────────┼────────────┐
       │            │            │
    SageGUI      SageShell     SageFS
       │            │            │
       └────────────┼────────────┘
                    │
                 SageBoot
                    │
              ┌─────┴─────┐
              │           │
             ARM        RISC-V
              │           │
              └─────┬─────┘
                    │
                 RP2350
                    │
          ┌─────────┼─────────┐
          │         │         │
         LCD        SD       USB
          │         │         │
          └─────────┼─────────┘
                    │
              SagePocket
```

The 128 GB SD card then stops being merely "storage." It becomes the persistent world of the machine:

```text
                    128 GB
                      │
        ┌─────────────┼─────────────┐
        │             │             │
      System         Apps          User
        │             │             │
     SageFS        .sapp          Files
        │             │             │
        └─────────────┼─────────────┘
                      │
                    ROMs
                      │
             ┌────────┼────────┐
             │        │        │
           Apple II  Z80    Game Boy
```

The final objective is therefore not simply **"Sage running on an RP2350."**

It is:

> **A complete, portable Sage computer whose operating system, filesystem, virtual machine, graphical environment, applications, development tools, and architecture backends form one coherent Sage ecosystem.**

That makes the RP2350-LCD-1.47-A an unusually good physical reference platform for the broader SageLang/SageVM/SageOS project.

The hardware assumptions above are based on the current Waveshare and Raspberry Pi documentation; in particular, the board's official examples confirm the FAT32 TF-card path and ST7789V3 LCD architecture. ([Waveshare][1])

For implementation, I would start with **Phases 0–3 only**: repository → SageBoot → LCD → SD. Once those four pieces work in Sage, the rest of SageOS has a real hardware foundation rather than being developed against assumptions.

[1]: https://www.waveshare.com/wiki/RP2350-LCD-1.47-A?utm_source=chatgpt.com "RP2350-LCD-1.47-A - Waveshare Wiki"
[2]: https://www.raspberrypi.com/products/rp2350/?utm_source=chatgpt.com "Buy an RP2350 – Raspberry Pi"
[3]: https://www.waveshare.com/wiki/1.47inch_LCD_Module?utm_source=chatgpt.com "1.47inch LCD Module - Waveshare Wiki"
[4]: https://www.raspberrypi.com/documentation/microcontrollers/microcontroller-chips.html?utm_source=chatgpt.com "Microcontroller chips - Raspberry Pi Documentation"
[5]: https://www.waveshare.com/rp2350-lcd-1.47-a.htm?sku=30569&utm_source=chatgpt.com "RP2350 1.47inch Display Development Board, 172×320, 262K Color, Based On RP2350 Dual-core & Dual-architecture Microcontroller, 150MHz Running Frequency, With Colorful RGB LED | RP2350-Touch-AMOLED-1.43"
