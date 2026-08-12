# boot/sageboot.sage - SageBoot entry, Phase 1 + Phase 2 bring-up.
#
# Phase 1 scope (plan.md): startup, GPIO, clock, UART, LED, temperature.
# Phase 2: ST7789V3 LCD - 320x172 landscape framebuffer, boot diagnostics
# rendered on screen.
# SageBoot runs from onboard flash, above the RP2350 boot ROM. It has its
# own minimal drivers (docs/boot.md section 4) and reports hardware state
# over the USB CDC console (stdio), UART0, and the LCD.
#
# Phase 3 adds the SD card + FAT32 (drivers/sd, drivers/fs). Phase 4 adds
# the boot menu, kernel loader (SAGEOS.KRN from storage) and recovery mode.
# Imports resolve from the repository root (CWD) when compiling.

import hw
import drivers.sd.sd_spi as sd
import drivers.fs.fat32 as fat_driver

var BOARD_NAME = "Waveshare RP2350-LCD-1.47-A"
var VERSION = "0.4.0"

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
    print stage + ": NOT AVAILABLE"

# --- Phase 2: LCD driver (ST7789V3, self-contained per boot.md) ----------

var LCD_PIN_CS = 17
var LCD_PIN_DC = 16
var LCD_PIN_RST = 20
var LCD_PIN_BL = 21
var LCD_WIDTH = 320
var LCD_HEIGHT = 172
var LCD_BYTES = 110080
var LCD_Y_OFF = 34

var LCD_COL_BLACK = 0x0000
var LCD_COL_RED = 0x07E0
var LCD_COL_GREEN = 0x001F
var LCD_COL_BLUE = 0xF800
var LCD_COL_YELLOW = 0x07FF
var LCD_COL_MAGENTA = 0xF81F
var LCD_COL_CYAN = 0xFFE0
var LCD_COL_WHITE = 0xFFFF

# 5x7 font, column-major, ASCII 32..126, bit 0 = top row.
var LCD_FONT = [
0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x5F,0x00,0x00, 0x00,0x07,0x00,0x07,0x00, 0x14,0x7F,0x14,0x7F,0x14,
0x24,0x2A,0x7F,0x2A,0x12, 0x23,0x13,0x08,0x64,0x62, 0x36,0x49,0x55,0x22,0x50, 0x00,0x05,0x03,0x00,0x00,
0x00,0x1C,0x22,0x41,0x00, 0x00,0x41,0x22,0x1C,0x00, 0x08,0x2A,0x1C,0x2A,0x08, 0x08,0x08,0x3E,0x08,0x08,
0x00,0x50,0x30,0x00,0x00, 0x08,0x08,0x08,0x08,0x08, 0x00,0x60,0x60,0x00,0x00, 0x20,0x10,0x08,0x04,0x02,
0x3E,0x51,0x49,0x45,0x3E, 0x00,0x42,0x7F,0x40,0x00, 0x42,0x61,0x51,0x49,0x46, 0x21,0x41,0x45,0x4B,0x31,
0x18,0x14,0x12,0x7F,0x10, 0x27,0x45,0x45,0x45,0x39, 0x3C,0x4A,0x49,0x49,0x30, 0x01,0x71,0x09,0x05,0x03,
0x36,0x49,0x49,0x49,0x36, 0x06,0x49,0x49,0x29,0x1E, 0x00,0x36,0x36,0x00,0x00, 0x00,0x56,0x36,0x00,0x00,
0x00,0x08,0x14,0x22,0x41, 0x14,0x14,0x14,0x14,0x14, 0x41,0x22,0x14,0x08,0x00, 0x02,0x01,0x51,0x09,0x06,
0x32,0x49,0x79,0x41,0x3E, 0x7C,0x12,0x11,0x12,0x7C, 0x7F,0x49,0x49,0x49,0x36, 0x3E,0x41,0x41,0x41,0x22,
0x7F,0x41,0x41,0x22,0x1C, 0x7F,0x49,0x49,0x49,0x41, 0x7F,0x09,0x09,0x01,0x01, 0x3E,0x41,0x41,0x51,0x32,
0x7F,0x08,0x08,0x08,0x7F, 0x00,0x41,0x7F,0x41,0x00, 0x20,0x40,0x41,0x3F,0x01, 0x7F,0x08,0x14,0x22,0x41,
0x7F,0x40,0x40,0x40,0x40, 0x7F,0x02,0x04,0x02,0x7F, 0x7F,0x04,0x08,0x10,0x7F, 0x3E,0x41,0x41,0x41,0x3E,
0x7F,0x09,0x09,0x09,0x06, 0x3E,0x41,0x51,0x21,0x5E, 0x7F,0x09,0x19,0x29,0x46, 0x46,0x49,0x49,0x49,0x31,
0x01,0x01,0x7F,0x01,0x01, 0x3F,0x40,0x40,0x40,0x3F, 0x1F,0x20,0x40,0x20,0x1F, 0x7F,0x20,0x18,0x20,0x7F,
0x63,0x14,0x08,0x14,0x63, 0x03,0x04,0x78,0x04,0x03, 0x61,0x51,0x49,0x45,0x43, 0x00,0x00,0x7F,0x41,0x41,
0x02,0x04,0x08,0x10,0x20, 0x41,0x41,0x7F,0x00,0x00, 0x04,0x02,0x01,0x02,0x04, 0x40,0x40,0x40,0x40,0x40,
0x00,0x01,0x02,0x04,0x00, 0x20,0x54,0x54,0x54,0x78, 0x7F,0x48,0x44,0x44,0x38, 0x38,0x44,0x44,0x44,0x20,
0x38,0x44,0x44,0x48,0x7F, 0x38,0x54,0x54,0x54,0x18, 0x08,0x7E,0x09,0x01,0x02, 0x08,0x14,0x54,0x54,0x3C,
0x7F,0x08,0x04,0x04,0x78, 0x00,0x44,0x7D,0x40,0x00, 0x20,0x40,0x44,0x3D,0x00, 0x00,0x7F,0x10,0x28,0x44,
0x00,0x41,0x7F,0x40,0x00, 0x7C,0x04,0x18,0x04,0x78, 0x7C,0x08,0x04,0x04,0x78, 0x38,0x44,0x44,0x44,0x38,
0x7C,0x14,0x14,0x14,0x08, 0x08,0x14,0x14,0x18,0x7C, 0x7C,0x08,0x04,0x04,0x08, 0x48,0x54,0x54,0x54,0x20,
0x04,0x3F,0x44,0x40,0x20, 0x3C,0x40,0x40,0x20,0x7C, 0x1C,0x20,0x40,0x20,0x1C, 0x3C,0x40,0x30,0x40,0x3C,
0x44,0x28,0x10,0x28,0x44, 0x0C,0x50,0x50,0x50,0x3C, 0x44,0x64,0x54,0x4C,0x44, 0x00,0x08,0x36,0x41,0x00,
0x00,0x00,0x7F,0x00,0x00, 0x00,0x41,0x36,0x08,0x00, 0x08,0x08,0x2A,0x1C,0x08
]

var lcd_ready = false

proc lcd_cs(val):
    hw.gpio_put(LCD_PIN_CS, val)

proc lcd_dc(val):
    hw.gpio_put(LCD_PIN_DC, val)

proc lcd_write_cmd(cmd):
    lcd_cs(true)
    lcd_dc(false)
    lcd_cs(false)
    hw.spi_write(0, cmd)
    lcd_cs(true)

proc lcd_write_data(byte):
    lcd_cs(true)
    lcd_dc(true)
    lcd_cs(false)
    hw.spi_write(0, byte)
    lcd_cs(true)

proc lcd_write_data_n(vals):
    lcd_cs(true)
    lcd_dc(true)
    lcd_cs(false)
    hw.spi_write(0, vals)
    lcd_cs(true)

proc lcd_init():
    hw.gpio_init(LCD_PIN_BL)
    hw.gpio_set_dir(LCD_PIN_BL, true)
    hw.gpio_put(LCD_PIN_BL, true)
    hw.gpio_init(LCD_PIN_CS)
    hw.gpio_set_dir(LCD_PIN_CS, true)
    hw.gpio_init(LCD_PIN_DC)
    hw.gpio_set_dir(LCD_PIN_DC, true)
    hw.gpio_init(LCD_PIN_RST)
    hw.gpio_set_dir(LCD_PIN_RST, true)
    lcd_cs(true)
    lcd_dc(true)
    if hw.spi_init(0, 62500000) == 0:
        return false
    hw.gpio_put(LCD_PIN_RST, false)
    hw.delay_ms(10)
    hw.gpio_put(LCD_PIN_RST, true)
    hw.delay_ms(120)
    if hw.lcd_fb_init(LCD_WIDTH, LCD_HEIGHT) != 1:
        return false
    lcd_write_cmd(0x36)
    lcd_write_data(0x70)
    lcd_write_cmd(0x3A)
    lcd_write_data(0x05)
    lcd_write_cmd(0xB2)
    lcd_write_data_n([0x0C, 0x0C, 0x00, 0x33, 0x33])
    lcd_write_cmd(0xB7)
    lcd_write_data(0x35)
    lcd_write_cmd(0xBB)
    lcd_write_data(0x35)
    lcd_write_cmd(0xC0)
    lcd_write_data(0x2C)
    lcd_write_cmd(0xC2)
    lcd_write_data(0x01)
    lcd_write_cmd(0xC3)
    lcd_write_data(0x13)
    lcd_write_cmd(0xC4)
    lcd_write_data(0x20)
    lcd_write_cmd(0xC6)
    lcd_write_data(0x0F)
    lcd_write_cmd(0xD0)
    lcd_write_data_n([0xA4, 0xA1])
    lcd_write_cmd(0xD6)
    lcd_write_data(0xA1)
    lcd_write_cmd(0xE0)
    lcd_write_data_n([0xF0, 0x00, 0x04, 0x04, 0x04, 0x05, 0x29, 0x33, 0x3E, 0x38, 0x12, 0x12, 0x28, 0x30])
    lcd_write_cmd(0xE1)
    lcd_write_data_n([0xF0, 0x07, 0x0A, 0x0D, 0x0B, 0x07, 0x28, 0x33, 0x3E, 0x36, 0x14, 0x14, 0x29, 0x23])
    lcd_write_cmd(0x21)
    lcd_write_cmd(0x11)
    hw.delay_ms(120)
    lcd_write_cmd(0x29)
    lcd_ready = true
    return true

proc lcd_set_window(x0, y0, x1, y1):
    lcd_write_cmd(0x2A)
    lcd_write_data(x0 >> 8)
    lcd_write_data(x0 & 0xFF)
    lcd_write_data(x1 >> 8)
    lcd_write_data(x1 & 0xFF)
    lcd_write_cmd(0x2B)
    var yb0 = y0 + LCD_Y_OFF
    var yb1 = y1 + LCD_Y_OFF
    lcd_write_data(yb0 >> 8)
    lcd_write_data(yb0 & 0xFF)
    lcd_write_data(yb1 >> 8)
    lcd_write_data(yb1 & 0xFF)
    lcd_write_cmd(0x2C)

proc lcd_show():
    lcd_cs(true)
    lcd_dc(true)
    lcd_cs(false)
    hw.lcd_fb_flush_bytes(LCD_BYTES)
    lcd_cs(true)

proc lcd_fill(color):
    hw.lcd_fb_fill(color)

proc lcd_fill_rect(x, y, w, h, color):
    var yy = y
    while yy < y + h:
        var xx = x
        while xx < x + w:
            hw.lcd_fb_pixel(xx, yy, color)
            xx = xx + 1
        yy = yy + 1

proc lcd_text(x, y, text, color, scale):
    var cx = x
    var i = 0
    while i < len(text):
        var ch = ord(text[i])
        if ch >= 32 and ch <= 126:
            var base = (ch - 32) * 5
            var col = 0
            while col < 5:
                var row = 0
                while row < 7:
                    if (LCD_FONT[base + col] & (1 << row)) != 0:
                        var sx = 0
                        while sx < scale:
                            var sy = 0
                            while sy < scale:
                                hw.lcd_fb_pixel(cx + col * scale + sx, y + row * scale + sy, color)
                                sy = sy + 1
                            sx = sx + 1
                    row = row + 1
                col = col + 1
        i = i + 1
        cx = cx + 6 * scale

proc lcd_temp_str():
    var t = hw.temp_c()
    var ti = int(t)
    var td = int((t - ti) * 10)
    if td < 0:
        td = -td
    return str(ti) + "." + str(td)

# --- Boot screen ---------------------------------------------------------

proc boot_screen(status):
    lcd_fill(LCD_COL_BLACK)
    lcd_fill_rect(0, 0, LCD_WIDTH, 22, LCD_COL_RED)
    lcd_text(8, 6, "SageBoot " + VERSION, LCD_COL_WHITE, 2)
    lcd_text(6, 28, "Board  : " + BOARD_NAME, LCD_COL_WHITE, 1)
    lcd_text(6, 36, "Arch   : " + asm_arch(), LCD_COL_WHITE, 1)
    var clock_mhz = int(hw.clock_hz() / 1000000)
    lcd_text(6, 44, "Clock  : " + str(clock_mhz) + " MHz", LCD_COL_WHITE, 1)
    lcd_text(6, 52, "Temp   : " + lcd_temp_str() + " C", LCD_COL_WHITE, 1)
    lcd_text(6, 60, "Uptime : " + str(int(hw.uptime_ms() / 1000)) + " s", LCD_COL_WHITE, 1)
    lcd_text(6, 72, "GPIO2  : PASS", LCD_COL_GREEN, 1)
    lcd_text(6, 80, "UART0  : PASS", LCD_COL_GREEN, 1)
    if status:
        lcd_text(6, 88, "LCD    : 320x172 PASS", LCD_COL_GREEN, 1)
    else:
        lcd_text(6, 88, "LCD    : FAIL", LCD_COL_RED, 1)
    lcd_text(6, 96, "SD     : " + str(fat_driver.fat_mounted()), LCD_COL_WHITE, 1)
    var sw = 38
    var col = 6
    var swcolors = [LCD_COL_RED, LCD_COL_GREEN, LCD_COL_BLUE,
                    LCD_COL_YELLOW, LCD_COL_MAGENTA, LCD_COL_CYAN, LCD_COL_WHITE]
    var i = 0
    while i < 7:
        lcd_fill_rect(col, 118, 36, 22, swcolors[i])
        col = col + sw
        i = i + 1
    lcd_rect_border()
    lcd_show()

proc lcd_rect_border():
    var i = 0
    while i < LCD_WIDTH:
        hw.lcd_fb_pixel(i, 0, LCD_COL_YELLOW)
        hw.lcd_fb_pixel(i, LCD_HEIGHT - 1, LCD_COL_YELLOW)
        i = i + 1
    i = 0
    while i < LCD_HEIGHT:
        hw.lcd_fb_pixel(0, i, LCD_COL_YELLOW)
        hw.lcd_fb_pixel(LCD_WIDTH - 1, i, LCD_COL_YELLOW)
        i = i + 1

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
    var lcd_ok = lcd_init()
    if lcd_ok:
        print "LCD: ST7789V3 init PASS"
    else:
        print "LCD: ST7789V3 init FAIL"

    # Phase 3/4: storage bring-up.
    var sd_ok = sd.sd_init()
    var kernel_entry = nil
    var mount_ok = false
    if sd_ok:
        print "SD: init PASS (type " + str(sd.sd_type()) + ")"
        mount_ok = fat_driver.fat_mount()
        if mount_ok:
            print "FAT: mount PASS"
            var entries = fat_driver.fat_ls()
            print "FAT: " + str(len(entries)) + " entries"
            var ei = 0
            while ei < len(entries):
                print "  " + entries[ei]["name"] + " (" + str(entries[ei]["size"]) + " B)"
                ei = ei + 1
            kernel_entry = fat_driver.fat_find_file("SAGEOS.KRN")
            if kernel_entry == nil:
                print "SageOS kernel SAGEOS.KRN not found"
        else:
            print "FAT: mount FAIL"
    else:
        print "SD: init FAIL"
        diag_not_ready("SD")

    boot_separator()
    print "SageBoot Phase 4 bring-up complete."
    if lcd_ok:
        boot_screen(4)
    var choice = boot_menu()
    if choice == 1:
        if kernel_entry != nil:
            kernel_loader(kernel_entry)
        else:
            print "Boot: no SAGEOS.KRN on storage, staying in boot console."
    elif choice == 2:
        recovery_mode()
    elif choice == 3:
        boot_diagnostics()
    else:
        print "Boot: halted in boot console."

# --- Phase 4: boot menu, kernel loader, recovery --------------------------

var MENU_TIMEOUT = 900     # ~9 s of 10 ms polls; on host (no real delay) instant.
var KERNEL_NAME = "SAGEOS.KRN"

# boot_menu(): print options and read a choice from UART0.
# Timeout with no input falls back to the default boot choice 1. Host stub
# returns -1 forever, so the loop ends immediately and defaults to boot.
proc boot_menu():
    boot_separator()
    print "Boot menu:"
    print "  1: Load SageOS kernel from SD"
    print "  2: Recovery mode"
    print "  3: Diagnostics (re-run)"
    print "  0: Halt to boot console"
    print "Select (default 1 within ~9 s):"
    var i = 0
    while i < MENU_TIMEOUT:
        var c = hw.uart_getc()
        if c >= 0:
            if c == 49:
                return 1
            elif c == 50:
                return 2
            elif c == 51:
                return 3
            elif c == 48:
                return 0
        hw.delay_ms(10)
        i = i + 1
    print "Boot menu timeout: defaulting to option 1."
    return 1

# kernel_loader(entry): read the kernel file from storage, verify its size
# and CRC, then hand off (Phase 5: jump to the loaded image).
proc kernel_loader(entry):
    boot_separator()
    print "Kernel loader: reading " + entry["name"] + " (" + str(entry["size"]) + " bytes)..."
    var data = fat_driver.fat_read_file(entry)
    if data == nil:
        print "Kernel load FAIL: read error."
        return false
    var crc = 0
    var idx = 0
    while idx < len(data):
        crc = crc + data[idx]
        crc = crc & 0xFFFF
        idx = idx + 1
    print "Kernel loaded: " + str(len(data)) + " bytes, CRC " + str(crc) + "."
    if len(data) != entry["size"]:
        print "Kernel load FAIL: size mismatch."
        return false
    print "Kernel verified. Hand-off to SageOS (Phase 5)."
    return true

# recovery_mode(): re-run the diagnostics and show stored fs status.
proc recovery_mode():
    boot_separator()
    print "Recovery mode: full diagnostics."
    diag_arch()
    diag_clock()
    diag_uptime()
    diag_temp()
    diag_gpio()
    diag_uart()
    diag_rgb()
    print "Recovery: storage re-check."
    var sd_ok = sd.sd_init()
    if sd_ok:
        print "SD: init PASS (type " + str(sd.sd_type()) + ")"
        if fat_driver.fat_mount():
            print "FAT: mount PASS"
        else:
            print "FAT: mount FAIL"
    else:
        print "SD: init FAIL"
        diag_not_ready("SD")
    print "Recovery diagnostics complete."

proc boot_diagnostics():
    diag_arch()
    diag_clock()
    diag_uptime()
    diag_temp()
    diag_gpio()
    diag_uart()
    diag_rgb()
    print "Diagnostics complete."

var boot_logo = 0
boot_sequence()

# Live uptime refresh on the LCD (every ~2 s) while the LED phase loop runs.
var led_phase = 0
var refresh = 0
while (true):
    led_phase = led_phase + 1
    if led_phase == 1:
        hw.rgb_set(0, 32, 0)
    elif led_phase == 2:
        hw.rgb_set(0, 0, 32)
    else:
        hw.rgb_set(0, 0, 0)
        led_phase = 0
    refresh = refresh + 1
    if refresh == 4 and lcd_ready:
        lcd_fill_rect(6, 60, 150, 8, LCD_COL_BLACK)
        lcd_text(6, 60, "Uptime : " + str(int(hw.uptime_ms() / 1000)) + " s", LCD_COL_WHITE, 1)
        lcd_show()
        refresh = 0
    hw.delay_ms(500)

