# sagefs/block.sage - block device layer.
#
# A block device is any module or dict exposing the standard interface:
#
#   bd_read(blockno)   -> array of 512 bytes, or nil on failure
#   bd_write(blockno, data) -> bool
#   bd_blocks()        -> number of 512-byte blocks
#
# This file provides a RAM disk implementation used by host-side tests,
# the Phase 6 demo, and any in-RAM scratch space on the pico. The SD card
# driver (drivers/sd/sd_spi.sage) is adapted to this interface by
# drivers/fs/fat32.sage via fat_set_blockdev(); a cacheable wrapper is
# provided by sagefs/cache.sage.

var BLOCK_SIZE = 512

var _ram_blocks = 0
var _ram_data = []

# block_ram_init(blocks): (re)allocate a RAM disk of zeros.
proc block_ram_init(blocks):
    _ram_blocks = blocks
    _ram_data = []
    var i = 0
    while i < blocks:
        var b = []
        var j = 0
        while j < BLOCK_SIZE:
            push(b, 0)
            j = j + 1
        push(_ram_data, b)
        i = i + 1

# block_ram_read(n): one 512-byte block, nil if out of range.
proc block_ram_read(n):
    if n < 0 or n >= _ram_blocks:
        return nil
    return _ram_data[n]

# block_ram_write(n, data): store one block, true on success.
proc block_ram_write(n, data):
    if n < 0 or n >= _ram_blocks:
        return false
    if len(data) != BLOCK_SIZE:
        return false
    _ram_data[n] = data
    return true

proc block_ram_count():
    return _ram_blocks

# block_ram_device(): dict of procs implementing the block device interface
# over the current RAM disk.
proc block_ram_device():
    return {"bd_read": block_ram_read, "bd_write": block_ram_write,
            "bd_blocks": block_ram_count}

# block_fill(data, byteval): convenience - rebuild a block filled with one
# byte value (used by mkfs).
proc block_fill(data, byteval):
    var i = 0
    while i < len(data):
        data[i] = byteval
        i = i + 1
    return data

# block_blank(): a fresh zero-filled 512-byte block.
proc block_blank():
    var out = []
    var i = 0
    while i < BLOCK_SIZE:
        push(out, 0)
        i = i + 1
    return out

# block_dump(data, off, count): printable hex string for diagnostics.
proc block_dump(data, off, count):
    var hexd = "0123456789ABCDEF"
    var s = ""
    var i = 0
    while i < count and off + i < len(data):
        var v = data[off + i]
        s = s + hexd[v / 16] + hexd[v % 16]
        if i != count - 1:
            s = s + " "
        i = i + 1
    return s