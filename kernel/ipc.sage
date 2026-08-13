# kernel/ipc.sage - Mailboxes and blocking receive for SageOS.
#
# Cooperative IPC: ipc_recv() marks the current task BLOCKED when the
# mailbox is empty; the scheduler then runs other tasks. A sender that
# puts a message wakes ONE blocked task per message (proc_wake). Because
# this is a cooperative kernel, a blocked receiver simply isn't scheduled
# until the kernel marks it READY again.
#
# API:
#   ipc_mailbox_create(cap) -> mbox
#   ipc_send(mbox, msg)     non-blocking, drops when full, wakes sleepers
#   ipc_recv(mbox) -> msg   blocks the current task until an item arrives
#   ipc_try_recv(mbox)      non-blocking receive (nil when empty)
#   ipc_pending(mbox)       number of queued items

import kernel.process as process
import kernel.scheduler as scheduler

var _mailboxes = []
var _mb_next_id = 1

proc ipc_mailbox_create(cap):
    var mbox = {}
    mbox["id"] = _mb_next_id
    _mb_next_id = _mb_next_id + 1
    mbox["cap"] = cap
    mbox["items"] = []
    mbox["waiters"] = []
    push(_mailboxes, mbox)
    return mbox

proc _mb_find(mbox):
    var i = 0
    while i < len(_mailboxes):
        if _mailboxes[i]["id"] == mbox["id"]:
            return _mailboxes[i]
        i = i + 1
    return nil

proc ipc_pending(mbox):
    var m = _mb_find(mbox)
    if m == nil:
        return 0
    return len(m["items"])

proc ipc_send(mbox, msg):
    var m = _mb_find(mbox)
    if m == nil:
        return false
    if len(m["waiters"]) > 0:
        var wid = m["waiters"][0]
        var rest = []
        var i = 1
        while i < len(m["waiters"]):
            push(rest, m["waiters"][i])
            i = i + 1
        m["waiters"] = rest
        push(m["items"], msg)
        process.proc_wake(wid)
        return true
    if len(m["items"]) < m["cap"]:
        push(m["items"], msg)
        return true
    return false

proc ipc_try_recv(mbox):
    var m = _mb_find(mbox)
    if m == nil:
        return nil
    if len(m["items"]) == 0:
        return nil
    var msg = m["items"][0]
    var rest = []
    var i = 1
    while i < len(m["items"]):
        push(rest, m["items"][i])
        i = i + 1
    m["items"] = rest
    return msg

proc ipc_recv(mbox):
    var m = _mb_find(mbox)
    if m == nil:
        return nil
    if len(m["items"]) > 0:
        return ipc_try_recv(mbox)
    # Block the currently running task on this mailbox.
    var cur = scheduler.sched_current()
    if cur != nil:
        cur["state"] = process.TASK_BLOCKED
        cur["block_src"] = mbox["id"]
        push(m["waiters"], cur["id"])
    return nil