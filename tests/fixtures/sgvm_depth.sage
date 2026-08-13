# tests/fixtures/sgvm_depth.sage - guest hitting the VM's call-depth
# boundary: the engine must report "Error: Call depth limit exceeded"
# cleanly and let the VM survive (the 1024-frame limit is engine-side).

proc boom(n):
    return boom(n + 1)

var x = boom(0)
print "depth survivor"