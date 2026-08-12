# boot/sageboot.sage - SageBoot entry and Phase 1 hardware bring-up.
#
# Phase 1 scope (plan.md): startup, GPIO, clock, UART, LED, temperature.
# SageBoot runs from onboard flash, above the RP2350 boot ROM. It has its
# own minimal drivers (docs/boot.md section 4) and reports hardware state
# over the USB CDC console (stdio) and UART0.
#
# Phase 2 adds the LCD; Phase 3 adds the SD card. Until then the boot flow
# prints "NOT AVAILABLE" for those stages instead of claiming success.

import hw

var BOARD_NAME = "Waveshare RP2350-LCD-1.47-A"
var VERSION = "0.1.0"

proc boot_separator():
    print "----------------------------------------"

proc boot_header():
    print "SageBoot " + VERSION
    print "Board: " + BOARD_NAME
    boot_separator()

proc diag_arch():
    print "Arch: " + asm_arch()

proc diag_clock():
    print "Clock: " + str(hw.clock_hz()) + " Hz"

proc diag_uptime():
    print "Uptime: " + str(hw.uptime_ms()) + " ms"

proc diag_temp():
    print "Temp: " + str(hw.temp_c()) + " C"

proc diag_gpio():
    hw.gpio_init(2)
    hw.gpio_set_dir(2, true)
    hw.gpio_put(2, true)
    if hw.gpio_get(2):
        print "GPIO2 loopback: PASS"
    else:
        print "GPIO2 loopback: FAIL"

proc diag_uart():
    hw.uart_init(115200)
    hw.uart_puts("SageBoot " + VERSION + " on " + BOARD_NAME + "\r\n")
    hw.uart_puts("Arch: " + asm_arch() + "\r\n")
    hw.uart_puts("UART0 diagnostic output: OK\r\n")
    print "UART0: PASS"

proc diag_rgb():
    hw.rgb_set(255, 0, 0)
    hw.delay_ms(150)
    hw.rgb_set(0, 255, 0)
    hw.delay_ms(150)
    hw.rgb_set(0, 0, 255)
    hw.delay_ms(150)
    hw.rgb_set(0, 0, 0)
    print "RGB LED: PASS"

proc diag_not_ready(stage):
    print stage + ": NOT AVAILABLE IN PHASE 1"

proc boot_sequence():
    boot_header()
    diag_arch()
    diag_clock()
    diag_uptime()
    diag_temp()
    diag_gpio()
    diag_uart()
    diag_rgb()
    boot_separator()
    diag_not_ready("LCD")
    diag_not_ready("SD")
    boot_separator()
    print "SageBoot Phase 1 bring-up complete."
    print "Boot menu and recovery: not in Phase 1."

boot_sequence()

var led_phase = 0
while (true):
    led_phase = led_phase + 1
    if led_phase == 1:
        hw.rgb_set(0, 32, 0)
    elif led_phase == 2:
        hw.rgb_set(0, 0, 32)
    else:
        hw.rgb_set(0, 0, 0)
        led_phase = 0
    hw.delay_ms(500)
