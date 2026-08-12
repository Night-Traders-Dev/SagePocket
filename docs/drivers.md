# SagePocket Driver and SageHAL API

> **Version:** 0.1.0 · **Component:** drivers/ · **Related:** [architecture.md](architecture.md)

This document describes the hardware abstraction layer (SageHAL) and the
device drivers of SagePocket. Drivers are the only code allowed to touch
RP2350 registers; everything above them uses abstraction APIs.

---

## 1. Design Rules

1. **Applications never touch registers.** All hardware access flows
   Application → SageOS API → device subsystem → driver → hardware.
2. **Small, single-purpose drivers.** One driver per device family, no
   business logic in drivers.
3. **Register access lives in the HAL layer.** Driver code that names
   specific RP2350 registers lives under `drivers/` and is architecture-
   aware (ARM vs RISC-V builds differ only here).
4. **Block-oriented abstraction** for storage: the filesystem sees a
   `block_device`, not an SD card.

## 2. SageHAL API

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

Example application-facing display API:

```text
lcd.init()
lcd.clear()
lcd.pixel(x, y, color)
lcd.rectangle(...)
lcd.text(...)
lcd.flush()
```

## 3. Source Layout

```text
drivers/
├── lcd/
│   └── st7789v3.sage
├── sd/
│   └── sd_spi.sage
├── usb/
├── gpio/
├── uart/
├── spi/
├── i2c/
├── pwm/
├── adc/
├── pio/
├── rgb/
└── temperature/
```

## 4. LCD Driver (ST7789V3)

`drivers/lcd/st7789v3.sage` implements:

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

Frame format is RGB565 over 4-wire SPI. The driver cooperates with the
partial framebuffer strategy of SageGUI ([sagegui.md](sagegui.md) §1) — it
must support windowed/dirty-region updates efficiently.

## 5. SD Card Driver (SD over SPI)

`drivers/sd/sd_spi.sage` implements:

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

Exposed interface (block layer — the filesystem never sees SPI):

```text
block_device.read_sector()
block_device.write_sector()
```

## 6. USB

- USB 1.1 device mode (development protocol, mass storage in recovery)
- USB 1.1 host mode (keyboard input; future adapters)

```text
drivers/usb/
├── device/     sagectl protocol, mass storage
└── host/       HID keyboard, future hubs/adapters
```

See [applications.md](applications.md) §5 for the `sagectl` protocol.

## 7. RGB LED and Temperature

```text
drivers/rgb/          RGB LED control (boot state indication, notifications)
drivers/temperature/  Board temperature sensor (monitor, diagnostics,
                      thermal safeguards)
```

## 8. Diagnostics Integration

Drivers expose self-tests consumed by the boot diagnostic suite
(see [boot.md](boot.md) §3 and [hardware.md](hardware.md) §9):

```text
CPU, SRAM, FLASH, LCD, SD, RGB, GPIO, SPI, I²C, UART, USB, ADC,
temperature, timer, PIO
```

## 9. Definitions of Done

### Phase 1 — Hardware bring-up

- [ ] Startup code runs: GPIO, clock, UART
- [ ] RGB LED blinks (first Sage-controlled signal)
- [ ] Temperature sensor readable

### Phase 2 — LCD

- [ ] ST7789V3 initialized; framebuffer draws text and graphics primitives
- [ ] SageBoot displays diagnostics on the LCD

### Phase 3 — SD

- [ ] SD detected, initialized over SPI, block read/write working
- [ ] FAT32 enumerates directories (`sage> ls`)

Related docs: [architecture.md](architecture.md), [hardware.md](hardware.md),
[sageos.md](sageos.md), [sagefs.md](sagefs.md), [sagegui.md](sagegui.md).