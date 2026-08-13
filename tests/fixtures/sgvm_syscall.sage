# tests/fixtures/sgvm_syscall.sage - guest using the pocket syscall table
# (sageos module) plus the delegated math bridge. Runs twice: normal mode
# (full table) and safe mode (the engine blocks direct host function
# calls; mounts/disk_free are also removed from the table by the pocket).

import sageos
import math

print "sv: " + str(sageos.version())
print "up: " + str(sageos.uptime_ms())
print "mo: " + str(sageos.mounts())
print "df: " + str(sageos.disk_free())
print "abs: " + str(math.abs(0 - 5))
print "pow: " + str(sageos.power("shutdown"))