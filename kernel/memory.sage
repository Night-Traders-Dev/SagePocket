# kernel/memory.sage - Physical allocator + kernel heap for SageOS.
#
# Simple deterministic buddy-style block allocator over a fixed sram pool.
# The pool is a byte image in a Sage array (host tests and the compiled
# pico build share this code); addresses are offsets into the pool.
#
# API:
#   mem_init(total)            configure the pool (idempotent, safe fail)
#   mem_alloc(size) -> addr    lowest-fit scan, nil when out of memory
#   mem_free(addr)             return a block (nil-safe)
#   mem_stats() -> dict        {total, used, free, blocks, max_block}
#
# Pool layout: blocks are 2-byte headers (flags+len little-endian) with an
# 8-byte stride per block. bit 15 of the header word marks allocated
# (1=used, 0=free). A single free list is scanned on alloc (splitting),
# and freed blocks are merged with their neighbours when contiguous.

var MEM_FLAG_USED = 0x8000

var _mem_pool = []
var _mem_size = 0
var _mem_used = 0
var _mem_blocks = 0

proc _mem_hdr_len(addr):
    return (_mem_pool[addr] | (_mem_pool[addr + 1] << 8)) & 0x7FFF

proc _mem_hdr_used(addr):
    return (_mem_pool[addr] | (_mem_pool[addr + 1] << 8)) & MEM_FLAG_USED != 0

proc _mem_set_hdr(addr, len, used):
    var w = (len & 0x7FFF)
    if used:
        w = w | MEM_FLAG_USED
    _mem_pool[addr] = w & 0xFF
    _mem_pool[addr + 1] = (w >> 8) & 0xFF

proc mem_init(total):
    if len(_mem_pool) > 0:
        return
    _mem_size = total
    var i = 0
    while i < total:
        push(_mem_pool, 0)
        i = i + 1
    _mem_set_hdr(0, total - 8, false)
    _mem_used = 0
    _mem_blocks = 0

proc mem_alloc(size):
    if len(_mem_pool) == 0:
        mem_init(4096)
    if size < 1:
        return nil
    var addr = 0
    while addr + 8 <= _mem_size:
        if not _mem_hdr_used(addr):
            var blk = _mem_hdr_len(addr)
            if blk >= size:
                if blk >= size + 8:
                    _mem_set_hdr(addr, size, true)
                    _mem_set_hdr(addr + size + 8, blk - size - 8, false)
                else:
                    _mem_set_hdr(addr, blk, true)
                _mem_used = _mem_used + _mem_hdr_len(addr)
                _mem_blocks = _mem_blocks + 1
                return addr + 8
        addr = addr + _mem_hdr_len(addr) + 8
    return nil

proc mem_free(addr):
    if addr == nil:
        return
    if addr < 8 or addr >= _mem_size:
        return
    var hdr = addr - 8
    if not _mem_hdr_used(hdr):
        return
    var len = _mem_hdr_len(hdr)
    _mem_set_hdr(hdr, len, false)
    _mem_used = _mem_used - len
    _mem_blocks = _mem_blocks - 1
    if hdr + len + 8 < _mem_size and not _mem_hdr_used(hdr + len + 8):
        var next_len = _mem_hdr_len(hdr + len + 8)
        _mem_set_hdr(hdr, len + next_len + 8, false)

proc mem_stats():
    var free = 0
    var max_block = 0
    var addr = 0
    while addr + 8 <= _mem_size:
        var blk = _mem_hdr_len(addr)
        if not _mem_hdr_used(addr):
            free = free + blk
            if blk > max_block:
                max_block = blk
        addr = addr + blk + 8
    return {"total": _mem_size, "used": _mem_used, "free": free,
            "blocks": _mem_blocks, "max_block": max_block}