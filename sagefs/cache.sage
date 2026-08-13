# sagefs/cache.sage - read-through / write-through LRU block cache.
#
# Wraps any block device dict and adds an LRU cache in front of reads:
# reads hit the cache if the block was seen recently, writes go through to
# the device and update the cache (write-through - data is always on the
# backing store, so a crash cannot lose it).
#
# Blocks are keyed by their block number via two parallel arrays (the
# interpreter does not support numeric dictionary keys).
#
# cache_wrap(dev, max_blocks) -> new block device dict ({bd_read, bd_write,
# bd_blocks}) with caching; cache_stats() reports hits/misses.

var _c_dev = nil
var _c_max = 8
var _c_keys = []
var _c_vals = []
var _c_hits = 0
var _c_misses = 0

# cache_init(dev, max_blocks): (re)configure the cache. Passing nil for dev
# clears it.
proc cache_init(dev, max_blocks):
    _c_dev = dev
    _c_max = max_blocks
    _c_keys = []
    _c_vals = []
    _c_hits = 0
    _c_misses = 0

proc cache_stats():
    return {"hits": _c_hits, "misses": _c_misses}

# cache_index(n): position of block n in the LRU order, or -1.
proc cache_index(n):
    var i = 0
    while i < len(_c_keys):
        if _c_keys[i] == n:
            return i
        i = i + 1
    return -1

# cache_evict(): drop the least-recently-used block.
proc cache_evict():
    var kept = []
    var keptv = []
    var i = 1
    while i < len(_c_keys):
        push(kept, _c_keys[i])
        push(keptv, _c_vals[i])
        i = i + 1
    _c_keys = kept
    _c_vals = keptv

# cache_touch(n): move block n to the back of the LRU order (most recent),
# evicting the front if the cache is full.
proc cache_touch(n):
    var idx = cache_index(n)
    var val = nil
    if idx >= 0:
        val = _c_vals[idx]
    var kept = []
    var keptv = []
    var i = 0
    while i < len(_c_keys):
        if i != idx:
            push(kept, _c_keys[i])
            push(keptv, _c_vals[i])
        i = i + 1
    _c_keys = kept
    _c_vals = keptv
    push(_c_keys, n)
    push(_c_vals, val)
    while len(_c_keys) > _c_max:
        cache_evict()
    return n

# cache_has(n): true if block n is cached.
proc cache_has(n):
    return cache_index(n) >= 0

# cache_read(n): return the block, pulling it through from the device on a
# miss.
proc cache_read(n):
    var idx = cache_index(n)
    if idx >= 0:
        _c_hits = _c_hits + 1
        var v = _c_vals[idx]
        cache_touch(n)
        return v
    _c_misses = _c_misses + 1
    var rf = _c_dev["bd_read"]
    var data = rf(n)
    if data == nil:
        return nil
    push(_c_keys, n)
    push(_c_vals, data)
    cache_touch(n)
    return data

# cache_write(n, data): write through to the device and refresh the cache.
proc cache_write(n, data):
    var wf = _c_dev["bd_write"]
    if not wf(n, data):
        return false
    var idx = cache_index(n)
    if idx >= 0:
        _c_vals[idx] = data
        cache_touch(n)
    else:
        push(_c_keys, n)
        push(_c_vals, data)
        cache_touch(n)
    return true

# cache_wrap(dev, max_blocks): a block device dict with the cache on top.
proc cache_wrap(dev, max_blocks):
    cache_init(dev, max_blocks)
    var bf = _c_dev["bd_blocks"]
    return {"bd_read": cache_read, "bd_write": cache_write,
            "bd_blocks": bf}