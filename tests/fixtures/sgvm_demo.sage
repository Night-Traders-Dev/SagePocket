# tests/fixtures/sgvm_demo.sage - guest program for the vendored VM demo.
# Compiled by the self-hosting `sagevm compile` and executed by the
# composed VM inside the pocket interpreter (see tools/compose_sagevm.py).

proc fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

proc greet(name):
    var msg = "hello " + name
    return msg

var i = 0
while i < 10:
    print "fib(" + str(i) + ")=" + str(fib(i))
    i = i + 1

print greet("from sgvm")
print "guest program done"