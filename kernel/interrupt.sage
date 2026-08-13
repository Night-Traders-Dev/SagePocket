# kernel/interrupt.sage - Interrupt manager and deferred work for SageOS.
#
# On the host/interpreter the "interrupt" layer is a software-managed IRQ
# table: kernel.int_register() assigns handler ids, kernel.int_pend() flags
# that an IRQ fired, and kernel.int_poll() (called from the scheduler loop)
# runs due handlers in priority order. Heavy work is deferred into a kernel
# work queue processed one item per loop iteration, keeping handlers short.
#
# API:
#   int_register(prio) -> irq_id       reserve an IRQ line
#   int_pend(irq_id)                   mark the IRQ as ready to run
#   int_mask(irq_id) / int_unmask      suppress / allow the IRQ
#   int_defer(fn)                      queue a deferred kernel job
#   int_poll(now)                      run pending handlers + one job
#   int_stats() -> dict

var _irqs = []
var _pending = []
var _masked = []
var _deferred = []
var _next_irq = 1

proc int_register(prio):
    var irq_id = _next_irq
    _next_irq = _next_irq + 1
    push(_irqs, {"id": irq_id, "prio": prio, "handler": nil, "arg": nil})
    return irq_id

proc int_attach(irq_id, handler, arg):
    var i = 0
    while i < len(_irqs):
        if _irqs[i]["id"] == irq_id:
            _irqs[i]["handler"] = handler
            _irqs[i]["arg"] = arg
            return true
        i = i + 1
    return false

proc int_pend(irq_id):
    var i = 0
    while i < len(_irqs):
        if _irqs[i]["id"] == irq_id:
            push(_pending, irq_id)
            return true
        i = i + 1
    return false

proc int_mask(irq_id):
    push(_masked, irq_id)

proc int_unmask(irq_id):
    var out = []
    var i = 0
    while i < len(_masked):
        if _masked[i] != irq_id:
            push(out, _masked[i])
        i = i + 1
    _masked = out

proc int_defer(fn):
    push(_deferred, fn)

proc _is_masked(irq_id):
    var i = 0
    while i < len(_masked):
        if _masked[i] == irq_id:
            return true
        i = i + 1
    return false

proc _irq_by_id(irq_id):
    var i = 0
    while i < len(_irqs):
        if _irqs[i]["id"] == irq_id:
            return _irqs[i]
        i = i + 1
    return nil

# int_poll(now): run every pending, unmasked handler (highest prio first),
# then at most one deferred job. Returns the number of handlers run.
proc int_poll(now):
    var ran = 0
    var done = true
    while done:
        done = false
        var best = nil
        var best_i = -1
        var i = 0
        while i < len(_pending):
            var irq = _irq_by_id(_pending[i])
            if irq == nil or _is_masked(_pending[i]):
                i = i + 1
                continue
            if best == nil:
                best = irq
                best_i = i
            elif irq["prio"] > best["prio"]:
                best = irq
                best_i = i
            i = i + 1
        if best != nil:
            # remove from pending
            var rest = []
            i = 0
            while i < len(_pending):
                if i != best_i:
                    push(rest, _pending[i])
                i = i + 1
            _pending = rest
            if best["handler"] != nil:
                var h = best["handler"]
                h(best["arg"], now)
            ran = ran + 1
            done = true
    if len(_deferred) > 0 and ran == 0:
        var job = _deferred[0]
        var rest = []
        var i = 1
        while i < len(_deferred):
            push(rest, _deferred[i])
            i = i + 1
        _deferred = rest
        job(now)
    return ran

proc int_stats():
    return {"irqs": len(_irqs), "pending": len(_pending),
            "masked": len(_masked), "deferred": len(_deferred)}