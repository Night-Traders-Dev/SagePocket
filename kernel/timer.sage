# kernel/timer.sage - Tick, clock and one-shot timers for SageOS.
#
# The kernel runs a cooperative scheduler over a virtual millisecond clock:
#   kernel_tick_ms() advances the clock by the given number of ms (1 per
# scheduler round on the pico; tests advance it explicitly).
# hw.uptime_ms() is NOT used here so the kernel is fully unit-testable in
# the interpreter (which lacks the hw module).
#
# API:
#   time_now()           current virtual ms
#   time_uptime()        same as time_now() (alias for the system clock)
#   timer_create(ms, id) register a one-shot fired at now + ms
#   timer_fire_due()     called by the scheduler; runs due timers
#   timer_stats() -> dict

var _k_clock = 0
var _timers = []
var _timer_next_id = 1

proc _tick_ms(ms):
    _k_clock = _k_clock + ms

proc timer_tick(ms):
    _k_clock = _k_clock + ms

proc time_now():
    return _k_clock

proc time_uptime():
    return _k_clock

proc timer_create(ms, handler_id):
    var id = _timer_next_id
    _timer_next_id = _timer_next_id + 1
    push(_timers, {"id": id, "at": _k_clock + ms, "handler": handler_id})
    return id

proc timer_fire_due():
    var fired = []
    var i = 0
    while i < len(_timers):
        if _timers[i]["at"] <= _k_clock:
            push(fired, _timers[i]["handler"])
        i = i + 1
    var j = 0
    while j < len(fired):
        # handler id is dispatched by the kernel (see kernel.sage); this
        # module only removes the timer from the due list.
        j = j + 1
    # prune fired timers
    var keep = []
    i = 0
    while i < len(_timers):
        if _timers[i]["at"] > _k_clock:
            push(keep, _timers[i])
        i = i + 1
    _timers = keep
    return fired

proc timer_stats():
    return {"clock": _k_clock, "pending": len(_timers), "next_id": _timer_next_id}