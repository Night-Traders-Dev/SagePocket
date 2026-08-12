# tests/unit/basic.sage - pure-Sage unit test (no hw, runs in the interpreter).
# expect: 55
# expect: 3.5
# expect: hello world
# expect: dict ok

proc add(x, y):
    return x + y

var sum = 0
var i = 0
while (i <= 10):
    sum = sum + i
    i = i + 1
print sum

print 1.5 + 2.0

print "hello " + "world"

var d = {"a": 1, "b": 2}
if len(d) == 2 and d["a"] == 1:
    print "dict ok"
else:
    print "dict broken"

print add(20, 35)
