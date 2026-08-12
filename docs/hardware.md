# SagePocket Hardware Reference

> **Version:** 0.1.0 · **Target:** Waveshare RP2350-LCD-1.47-A

This document is the hardware reference for the SagePocket platform. It
describes the board, the RP2350 microcontroller, the onboard peripherals, and
the way SagePocket partitions the available resources.

> **Note:** Hardware facts below are based on the current Waveshare and
> Raspberry Pi public documentation (board wiki, product page, RP2350
> datasheet references). Any register-level detail must be verified against
> the official RP2350 datasheet and the board schematic before use.

---

## 1. Board Overview

The platform is built on the **Waveshare RP2350-LCD-1.47-A** development
board.

```text
RP2350A
 ├── dual Cortex-M33 option (ARM)
 ├── dual Hazard3 option (RISC-V)
 ├── up to 150 MHz
 ├── 520 KB SRAM
 └── 16 MB W25Q128-series NOR flash

172×320 IPS LCD (ST7789V3) over SPI
TF/microSD slot
USB 1.1 (device + host)
RGB LED
Hardware reset
Temperature sensor
GPIO, SPI, I²C, UART, PWM, ADC, PIO
```

## 2. RP2350 Microcontroller

| Property | Value |
|----------|-------|
| Cores | Dual Cortex-M33 *or* dual Hazard3 RISC-V (selected at boot) |
| Clock | Up to 150 MHz |
| SRAM | 520 KB |
| Flash support | External QSPI NOR (16 MB W25Q128-series on this board) |
| SPI controllers | 2 |
| I²C controllers | 2 |
| UARTs | 2 |
| PWM channels | 24 |
| USB | 1.1 (device and host) |
| PIO | 12 state machines |
| GPIO | 30 (typical) |
| On-chip ADC | Yes |
| Temperature sensor | Internal and board-level |

## 3. Peripherals on the Board

| Peripheral | Detail |
|------------|--------|
| Display | 172×320 IPS, ST7789V3 controller, 4-wire SPI |
| Storage | TF/microSD slot (SPI SD) |
| USB | USB 1.1, device + host support |
| RGB LED | Programmable color LED |
| Reset | Hardware reset button |
| Temperature sensor | Board temperature sensing |
| Debug | UART exposed for serial console |

### 3.0 Pin Map (verified 2026-08-11)

Source: official Waveshare `RP2350-LCD-1.47.zip` demo package (2025-03-04),
cross-checked with the board schematic. The same map is in
`boards/waveshare_rp2350_lcd_1_47.h` (C/SDK) and `boards/board.sage` (Sage).

```text
LCD ST7789V3 (SPI0)     SCK=18  MOSI=19  CS=17  DC=16  RST=20  BL=21
microSD (SPI1)          SCK=10  MOSI=11  MISO=12        CS=15
RGB LED (WS2812B)       GPIO22  (PIO, GRB, one LED)
I2C (module header)     i2c1: SDA=6  SCL=7
UART0 console           TX=0  RX=1
Flash                   W25Q128 (16 MB QSPI, not on GPIO)
Temp sensor             RP2350 internal ADC4
Buttons                 none (BOOT/RESET only)
```

### 3.1 Display (ST7789V3)

```text
Controller: ST7789V3
Resolution: 172 × 320 (portrait panel)
Interface:  4-wire SPI (SPI0)
Color:      RGB565, BGR byte order
```

The display is the primary graphical interface for SageOS. Waveshare documents
RGB565 operation and provides both low-level LCD and LVGL examples, making
partial-rendering demonstration code available as a bootstrap reference.

**Verified driver configuration (Phase 2, `drivers/lcd/st7789v3.sage`):**

```text
SPI:      SPI0 master, mode 0 (CPOL 0 / CPHA 0), MSB first, 62.5 MHz
          (pico SPI max = clk_sys/2; the MicroPython demo's 100 MHz
          nominal is clamped the same way)
Pins:     SCK=18  MOSI=19  CS=17  DC=16  RST=20  BL=21 (BL active high)
Orientation: landscape 320 × 172, MadCTL 0x36 = 0x70
Window:   CASET 0x2A = X 0..319 (no offset)
          RASET 0x2B = Y 34..205  (offset +0x22 = 34; the 172-pixel
          panel is centered in the controller's 240-row GRAM)
Flush:    set window -> RAMWR (0x2C) -> DC high, CS low -> 110,080
          bytes (320×172×2) -> CS high
```

Notes and gotchas:

- **The C demo's window offsets are buggy** (they push windows past GRAM
  limits: `X+0x22` on a 320-wide window, and `Y+0x22` beyond 205). The
  MicroPython demo (`RP2350-LCD-1.47.py`) is the tested reference and the
  numbers above follow it exactly.
- **BGR565 byte order**: with MadCTL RGB=0 the panel reads pixels as BGR.
  The demo's color constants are swapped accordingly (RED=0x07E0,
  GREEN=0x001F, BLUE=0xF800); `drivers/lcd/st7789v3.sage` uses the same
  convention.
- Init register sequence (0x36=0x70, 0x3A=0x05, B2/B7/BB/C0/C2/C3/C4/C6,
  D0/D6, gamma E0/E1, INVON 0x21, SLPOUT 0x11 + 120 ms, DISPON 0x29) is
  taken verbatim from the official demos; the two demos differ only in the
  last E1 gamma byte (0x23 vs 0x32) - the MicroPython value is used.
- The 110,080-byte framebuffer is C-backed (`hw.lcd_fb_*` natives); Sage
  drawing primitives write pixels into it and `lcd_show()` blasts it out.

### 3.2 Storage

```text
Primary removable storage:   128 GB microSD / TF
Bootstrap filesystem:        FAT32
Long-term filesystem:        SageFS
```

The initial system uses FAT32 because the board's official TF-card example
uses FAT32, giving a proven path to bootstrap from.

---

## 4. Memory Map (SRAM)

The RP2350 provides **520 KB SRAM**. SagePocket's initial partitioning target:

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

The full display framebuffer is:

```text
172 × 320 × 2 bytes = 110,080 bytes ≈ 107.5 KiB
```

Because this is a significant portion of SRAM, the GUI uses partial/tiled
rendering by default (see [sagegui.md](sagegui.md)). Full-framebuffer mode is
optional and only allocated when the memory profile proves worthwhile.

## 5. Flash Layout (16 MB NOR)

Onboard flash is reserved for system-critical code; applications and user
data live on the SD card.

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

The SD card contains:

```text
applications
user data
ROMs
assets
logs
cache
large libraries
```

## 6. System Image

The distribution artifact is `sagepocket.img`, containing:

```text
boot
kernel
system files
default configuration
filesystem metadata
```

Built with the host tool `sagepack-image`.

## 7. Performance Targets

Hardware capability targets (engineering targets, not guarantees):

```text
Boot to SageBoot:   < 1 second
Boot to SageOS:     < 3 seconds
Boot to GUI:        < 5 seconds
Shell response:     < 50 ms
GUI target:         30+ FPS
```

## 8. Diagnostics View

The `system` command reports the recognized hardware:

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

The `arch` command reports architecture selection:

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

## 9. Hardware Diagnostics

SageBoot and SageOS expose a diagnostic suite covering: CPU, SRAM, FLASH,
LCD, SD, RGB, GPIO, SPI, I²C, UART, USB, ADC, temperature, timer, PIO.

Example output:

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

See [boot.md](boot.md) for how diagnostics fit the boot flow.

## 10. SD Card Diagnostics

Because the SD card is critical to the platform, dedicated tools exist:

```text
sdinfo    card identity and geometry
sdtest    read/write correctness test
sdspeed   throughput measurement
sdfmt     (re)formatting
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

Actual speeds must be measured, never assumed.

## 11. References

- Waveshare RP2350-LCD-1.47-A wiki and product page
- Raspberry Pi RP2350 product page and microcontroller documentation
- RP2350 datasheet (register-level detail)
- Board schematic (pin mapping)

Related docs: [architecture.md](architecture.md), [boot.md](boot.md),
[drivers.md](drivers.md), [development.md](development.md).