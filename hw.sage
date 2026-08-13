# hw.sage - interpreter shim for the native hardware module.
#
# The SageLang compiler knows `hw` as a native module (pico targets emit
# real RP2350 calls through the prelude), so on the board this file is
# never read. The interpreter has no native `hw`, so module import chains
# that contain `import hw` (e.g. drivers.sd.sd_spi via fat32/fatfs) fail
# to load there. This shim keeps those imports working in the interpreter:
# every hardware call degrades to "device absent" (nil / false / empty),
# which the drivers already handle (e.g. sd_init() fails, fat_mount()
# returns false, and host smoke takes the no-card path).

# --- GPIO ------------------------------------------------------------------

proc gpio_init(pin):
    return false

proc gpio_set_dir(pin, out):
    return false

proc gpio_put(pin, val):
    return false

proc gpio_get(pin):
    return 0

proc gpio_set_pull(pin, up, down):
    return false

# --- clock -----------------------------------------------------------------

proc clock_hz():
    return 0

proc uptime_ms():
    return 0

proc delay_ms(ms):
    return false

proc delay_us(us):
    return false

# --- UART ------------------------------------------------------------------

proc uart_init(instance, baud):
    return false

proc uart_putc(instance, c):
    return false

proc uart_puts(instance, s):
    return false

# uart_getc(): -1 means "no byte available" on the host prelude; the boot
# menu relies on that to time out instantly.
proc uart_getc(instance):
    return -1

# --- ADC -------------------------------------------------------------------

proc adc_init():
    return false

proc adc_read():
    return 0

proc temp_c():
    return 0.0

# --- WS2812B ---------------------------------------------------------------

proc rgb_set(index, r, g, b):
    return false

# --- SPI -------------------------------------------------------------------

proc spi_init(instance, baud):
    return false

proc spi_write(instance, data):
    return false

proc spi_read(instance, count):
    var out = []
    var i = 0
    while i < count:
        push(out, 0xFF)
        i = i + 1
    return out

# --- LCD framebuffer ---------------------------------------------------------

var _fb = []

proc lcd_fb_init(width, height):
    return false

proc lcd_fb_pixel(x, y, rgb):
    return false

proc lcd_fb_fill(rgb):
    return false

proc lcd_fb_flush_bytes(countv):
    return nil