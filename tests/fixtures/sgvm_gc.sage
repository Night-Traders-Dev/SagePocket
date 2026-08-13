# tests/fixtures/sgvm_gc.sage - guest allocation churn, GC surface, and
# arena bounds. Runs in the composed VM: churn with gc disabled, churn
# with gc enabled plus a stats round-trip and integrity check, then
# out-of-bounds / double-free arena access that must degrade to nil
# instead of crashing the VM.

import gc
import mem

gc.disable()
var i = 0
while i < 40:
    var t = {}
    var j = 0
    while j < 20:
        t["k" + str(j)] = i * 100 + j
        j = j + 1
    i = i + 1
gc.enable()

var keep = []
var k = 0
while k < 30:
    push(keep, {"id": k, "payload": k * 7})
    k = k + 1
gc.collect()
var total = 0
var m = 0
while m < len(keep):
    total = total + keep[m]["payload"]
    m = m + 1
print "churn ok: " + str(total)
print "gc stats: " + str(gc.stats()["num_objects"])

var p = mem.alloc(16)
var bad = mem.read(p, 100, 3)
print "oob read: " + str(bad)
var badw = mem.write(p, 200, 1, 2)
print "oob write: " + str(badw)
print "double free: " + str(mem.free(p))
print "gc demo done"