# board.sage - Sage-side board constants for the Waveshare RP2350-LCD-1.47-A.
#
# These constants mirror boards/waveshare_rp2350_lcd_1_47.h so Sage code can
# address board peripherals without magic numbers. Pin assignments are
# verified against the official Waveshare RP2350-LCD-1.47 demo package and
# the board schematic.

# --- RP2350A ----------------------------------------------------------------
var CHIP_NAME = "RP2350A"
var CHIP_SRAM_KB = 520
var CHIP_FLASH_MB = 16
var CLOCK_MAX_MHZ = 150

# --- ST7789V3 LCD (172x320, SPI0) ------------------------------------------
var LCD_SPI = 0
var LCD_DC = 16
var LCD_CS = 17
var LCD_SCK = 18
var LCD_MOSI = 19
var LCD_RST = 20
var LCD_BL = 21
var LCD_WIDTH = 172
var LCD_HEIGHT = 320
var LCD_DEPTH_BITS = 16

# --- microSD slot (SPI1) -----------------------------------------------------
var SD_SPI = 1
var SD_SCK = 10
var SD_MOSI = 11
var SD_MISO = 12
var SD_CS = 15

# --- RGB LED (WS2812B, PIO) --------------------------------------------------
var RGB_PIN = 22

# --- I2C (LCD module connector, i2c1) ----------------------------------------
var I2C_BUS = 1
var I2C_SDA = 6
var I2C_SCL = 7

# --- UART console (LCD connector / header, UART0) ----------------------------
var UART_BUS = 0
var UART_TX = 0
var UART_RX = 1
