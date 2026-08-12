// Board header for the Waveshare RP2350-LCD-1.47-A.
//
// Pin assignments verified against the official Waveshare demo package
// (RP2350-LCD-1.47.zip, 2025-03-04) and the board schematic:
//   C/01-LCD/lib/Config/DEV_Config.h       LCD + I2C pins
//   Python/02-SD/boot.py                   SD (SPI1) pins
//   Python/03-RGB/WS2812B.py               RGB LED pin (PIO)
//
// This header is discovered by the pico-sdk via PICO_BOARD_HEADER_DIRS
// (see cmake/generic_board.cmake) when compiling with
// --board waveshare_rp2350_lcd_1_47.

#ifndef _BOARDS_WAVESHARE_RP2350_LCD_1_47_H
#define _BOARDS_WAVESHARE_RP2350_LCD_1_47_H

#include "boards/pico2.h"

// pico_cmake_set_default PICO_FLASH_SIZE_BYTES = (16 * 1024 * 1024)
// pico_cmake_set_default PICO_RP2350_A2_SUPPORTED = 1

// --- ST7789V3 LCD (172x320, 4-wire SPI, SPI0) -----------------------------

#define WAVESHARE_LCD_DC_PIN 16
#define WAVESHARE_LCD_CS_PIN 17
#define WAVESHARE_LCD_SCK_PIN 18
#define WAVESHARE_LCD_MOSI_PIN 19
#define WAVESHARE_LCD_RST_PIN 20
#define WAVESHARE_LCD_BL_PIN 21

#define PICO_DEFAULT_SPI 0
#define PICO_DEFAULT_SPI_SCK_PIN WAVESHARE_LCD_SCK_PIN
#define PICO_DEFAULT_SPI_TX_PIN WAVESHARE_LCD_MOSI_PIN
#define PICO_DEFAULT_SPI_CSN_PIN WAVESHARE_LCD_CS_PIN

// --- microSD slot (SPI1) ---------------------------------------------------

#define WAVESHARE_SD_SPI 1
#define WAVESHARE_SD_SCK_PIN 10
#define WAVESHARE_SD_MOSI_PIN 11
#define WAVESHARE_SD_MISO_PIN 12
#define WAVESHARE_SD_CS_PIN 15

// --- RGB LED (single WS2812B, PIO-driven) ----------------------------------

#define WAVESHARE_RGB_PIN 22

// --- I2C (LCD module connector, i2c1) --------------------------------------

#define PICO_DEFAULT_I2C 1
#define PICO_DEFAULT_I2C_SDA_PIN 6
#define PICO_DEFAULT_I2C_SCL_PIN 7

// --- UART (serial console on the LCD connector / header) --------------------

#define PICO_DEFAULT_UART 0
#define PICO_DEFAULT_UART_TX_PIN 0
#define PICO_DEFAULT_UART_RX_PIN 1

// --- UART on USB for stdio (pico_enable_stdio_usb is used) -----------------

// No user buttons on this board; only BOOT and RESET.

#endif
