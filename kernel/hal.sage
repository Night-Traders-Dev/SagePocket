# kernel/hal.sage - SageHAL: hardware abstraction layer for SagePocket.
#
# API (plan.md section 8): hal.cpu(), hal.memory(), hal.gpio(), hal.spi(),
# hal.i2c(), hal.uart(), hal.pwm(), hal.adc(), hal.timer(), hal.usb(),
# hal.pio(), hal.temperature().
#
# Applications must not depend on RP2350 register definitions directly;
# everything goes through this layer (or hw.*, which it wraps).
#
# Phase 1 scope: cpu, memory, gpio, uart, adc, timer, temperature.
# spi/i2c/pwm/usb/pio return nil until their phases land.

import hw

proc hal_cpu():
    var info = {}
    info["name"] = "RP2350A"
    info["arch"] = asm_arch()
    info["clock_hz"] = hw.clock_hz()
    info["sram_kb"] = 520
    info["flash_mb"] = 16
    return info

proc hal_memory():
    var info = {}
    info["sram_bytes"] = 520 * 1024
    info["flash_bytes"] = 16 * 1024 * 1024
    return info

proc hal_gpio_init(pin, output):
    hw.gpio_init(pin)
    hw.gpio_set_dir(pin, output)

proc hal_gpio_write(pin, value):
    hw.gpio_put(pin, value)

proc hal_gpio_read(pin):
    return hw.gpio_get(pin)

proc hal_gpio_set_pull(pin, up, down):
    hw.gpio_set_pull(pin, up, down)

proc hal_uart_init(baud):
    return hw.uart_init(baud)

proc hal_uart_puts(text):
    hw.uart_puts(text)

proc hal_uart_putc(ch):
    hw.uart_putc(ch)

proc hal_uart_getc():
    return hw.uart_getc()

proc hal_adc_init(pin):
    hw.adc_init(pin)

proc hal_adc_read(pin):
    return hw.adc_read(pin)

proc hal_timer_uptime_ms():
    return hw.uptime_ms()

proc hal_timer_delay_ms(ms):
    hw.delay_ms(ms)

proc hal_timer_delay_us(us):
    hw.delay_us(us)

proc hal_temperature_c():
    return hw.temp_c()

proc hal_clock_hz():
    return hw.clock_hz()

proc hal_spi():
    return nil

proc hal_i2c():
    return nil

proc hal_pwm():
    return nil

proc hal_usb():
    return nil

proc hal_pio():
    return nil
