# drivers/sd/sd_spi.sage - SD/SDHC card over SPI (Waveshare RP2350-LCD-1.47).
#
# Verified against the official MicroPython demo (sdcard.py, boot.py):
#   - SPI1 master, mode 0: SCK=10, MOSI=11, MISO=12, CS=15
#   - Init at 400 kHz, then switch to 20 MHz after CMD16
#   - SDv2 (CMD8 + HCS ACMD41) and SDv1 (ACMD41 without HCS) supported
#   - CS is held LOW across command + data phases for CMD17/CMD24
#     (the card aborts transfers if CS is raised mid-read).

import hw

var SD_CS = 15
var SD_BUS = 1
var SD_BAUD_LOW = 400000
var SD_BAUD_HIGH = 20000000

var SD_TYPE_NONE = 0
var SD_TYPE_V1 = 1
var SD_TYPE_V2 = 2

var _sd_ready = false
var _sd_type = SD_TYPE_NONE
var SD_BLOCK_SIZE = 512

proc _sd_cs(val):
    hw.gpio_put(SD_CS, val)

# sd_cmd(cmd, arg, crc, keep): send a 6-byte SPI command (CS low) and read
# the R1 response. With keep=true CS stays low after the response (data
# phase follows); otherwise CS is released and one dummy byte is clocked.
# Returns a dict {r1, d} where d holds up to 4 response payload bytes
# (always present, zero-filled), or nil on timeout.
proc sd_cmd(cmd, arg, crc, keep):
    if not _sd_ready:
        return nil
    _sd_cs(false)
    var frame = [
        0x40 | cmd,
        (arg >> 24) & 0xFF,
        (arg >> 16) & 0xFF,
        (arg >> 8) & 0xFF,
        arg & 0xFF,
        crc
    ]
    hw.spi_write(SD_BUS, frame)
    var r1 = -1
    var i = 0
    while i < 16:
        var b = hw.spi_read(SD_BUS, 1)
        if (b[0] & 0x80) == 0:
            r1 = b[0]
            break
        i = i + 1
    var d = [0, 0, 0, 0]
    if r1 >= 0 and not keep:
        var extra = hw.spi_read(SD_BUS, 4)
        d = [extra[0], extra[1], extra[2], extra[3]]
    if not keep:
        _sd_cs(true)
        hw.spi_read(SD_BUS, 1)
    if r1 < 0:
        return nil
    return {"r1": r1, "d": d}

# sd_wait_token(): clock bytes until the 0xFE data-start token.
proc sd_wait_token():
    var i = 0
    while i < 1000:
        var b = hw.spi_read(SD_BUS, 1)
        if b[0] == 0xFE:
            return true
        i = i + 1
    return false

# sd_init(): power the card up over SPI. Returns SD_TYPE_* on success,
# SD_TYPE_NONE on failure. Card type 2 = SDHC (block addressing),
# type 1 = SDSC (byte addressing, 512-byte blocks via CMD16).
proc sd_init():
    hw.gpio_init(SD_CS)
    hw.gpio_set_dir(SD_CS, true)
    _sd_cs(true)
    _sd_ready = false
    _sd_type = SD_TYPE_NONE
    if hw.spi_init(SD_BUS, SD_BAUD_LOW) == 0:
        return SD_TYPE_NONE
    var i = 0
    while i < 16:
        hw.spi_write(SD_BUS, 0xFF)
        i = i + 1
    var idle = false
    i = 0
    while i < 5:
        var r = sd_cmd(0, 0, 0x95, false)
        if r != nil and r["r1"] == 0x01:
            idle = true
            break
        i = i + 1
    if not idle:
        sd_done()
        return SD_TYPE_NONE
    var r8 = sd_cmd(8, 0x000001AA, 0x87, false)
    if r8 != nil and r8["r1"] == 0x01:
        var ok = false
        i = 0
        while i < 100:
            var r55 = sd_cmd(55, 0, 0, false)
            var r41 = sd_cmd(41, 0x40000000, 0, false)
            if r41 != nil and r41["r1"] == 0:
                ok = true
                break
            i = i + 1
        if not ok:
            sd_done()
            return SD_TYPE_NONE
        var ocr = sd_cmd(58, 0, 0, false)
        if ocr == nil:
            sd_done()
            return SD_TYPE_NONE
        if (ocr["d"][0] & 0x40) != 0:
            _sd_type = SD_TYPE_V2
        else:
            _sd_type = SD_TYPE_V1
    elif r8 != nil and r8["r1"] == 0x05:
        var ok = false
        i = 0
        while i < 100:
            var r55 = sd_cmd(55, 0, 0, false)
            var r41 = sd_cmd(41, 0, 0, false)
            if r41 != nil and r41["r1"] == 0:
                ok = true
                break
            i = i + 1
        if not ok:
            sd_done()
            return SD_TYPE_NONE
        _sd_type = SD_TYPE_V1
    else:
        sd_done()
        return SD_TYPE_NONE
    var r16 = sd_cmd(16, SD_BLOCK_SIZE, 0, false)
    if r16 == nil or r16["r1"] != 0:
        sd_done()
        return SD_TYPE_NONE
    _sd_ready = true
    hw.spi_init(SD_BUS, SD_BAUD_HIGH)
    return _sd_type

proc sd_done():
    _sd_ready = false
    _sd_cs(true)

proc sd_ready():
    return _sd_ready

proc sd_type():
    return _sd_type

# sd_read_block(lba): read one 512-byte sector. Returns an array of 512
# bytes, or nil on failure.
proc sd_read_block(lba):
    if not _sd_ready:
        return nil
    var r = sd_cmd(17, lba, 0, true)
    if r == nil or r["r1"] != 0:
        sd_done()
        return nil
    if not sd_wait_token():
        sd_done()
        return nil
    var data = hw.spi_read(SD_BUS, SD_BLOCK_SIZE + 2)
    var out = []
    var i = 0
    while i < SD_BLOCK_SIZE:
        push(out, data[i])
        i = i + 1
    _sd_cs(true)
    hw.spi_read(SD_BUS, 1)
    return out

# sd_write_block(lba, data): write one 512-byte sector (data must be an
# array of exactly 512 bytes). Returns true on success.
proc sd_write_block(lba, data):
    if not _sd_ready:
        return false
    if len(data) != SD_BLOCK_SIZE:
        return false
    var r = sd_cmd(24, lba, 0, true)
    if r == nil or r["r1"] != 0:
        sd_done()
        return false
    hw.spi_write(SD_BUS, 0xFE)
    hw.spi_write(SD_BUS, data)
    hw.spi_write(SD_BUS, [0xFF, 0xFF])
    var resp = hw.spi_read(SD_BUS, 1)
    if resp[0] != 0x05:
        sd_done()
        return false
    var i = 0
    while i < 1000:
        var b = hw.spi_read(SD_BUS, 1)
        if b[0] != 0x00:
            _sd_cs(true)
            hw.spi_read(SD_BUS, 1)
            return true
        i = i + 1
    sd_done()
    return false

# sd_read_blocks(lba, count): sequential single-block reads. Returns a
# flat array of count*512 bytes, or nil on failure.
proc sd_read_blocks(lba, count):
    if not _sd_ready:
        return nil
    var out = []
    var i = 0
    while i < count:
        var s = sd_read_block(lba + i)
        if s == nil:
            return nil
        var j = 0
        while j < SD_BLOCK_SIZE:
            push(out, s[j])
            j = j + 1
        i = i + 1
    return out