# tests/fixtures/sgvm_mem.sage - guest exercising the memory arena bridge.
# Runs twice: normal mode (typed arena round-trip through the native mem
# API - the pocket memory layer) and safe mode (the engine's "restricted
# in safe mode" guards must fire).

import mem

var p = mem.alloc(64)
print "alloc ptr: " + str(p)

var w = mem.write(p, 0, "int", 65)
print "write ok: " + str(w)

var v = mem.read(p, 0, "int")
print "read back: " + str(v)
print "read2: " + str(mem.read(p, 4, "int"))
print "size: " + str(mem.size(p))
print "free ok: " + str(mem.free(p))