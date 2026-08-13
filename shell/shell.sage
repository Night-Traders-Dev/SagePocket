# shell/shell.sage - SageShell REPL.
#
# Context: a dict carrying the shell state:
#   cwd   - absolute working directory
#   out   - output accumulator (string)
#   exit  - set by the "exit" command
#   io    - {"read": proc() -> one input line or nil at EOF,
#            "write": proc(text), "clear": proc()}
#   sys   - optional {"ps": proc(ctx, args), ...} hook table for system
#           commands (kernel services on the pico, host stubs, or the
#           interpreter shim); nil entries degrade to "not available".
#
# The prompt is "sage> " exactly once per line read; the loop ends at
# EOF (read returns nil) or when a command sets ctx["exit"].

import shell.parser as parser
import shell.commands as cmds

var PROMPT = "sage> "

# shell_ctx_new(io, sys): a fresh shell context rooted at "/".
proc shell_ctx_new(io, sys):
    return {"cwd": "/", "out": "", "exit": false, "io": io, "sys": sys}

# shell_run_line(ctx, line): parse and execute one command line. Returns
# ctx["out"] so callers can assert on accumulated output.
proc shell_run_line(ctx, line):
    var tokens = parser.parse_tokens(line)
    if len(tokens) == 0:
        return ctx["out"]
    var name = tokens[0]
    var args = []
    var i = 1
    while i < len(tokens):
        push(args, tokens[i])
        i = i + 1
    var cmd = cmds.shell_lookup(name)
    if cmd == nil:
        cmds.sh_err(ctx, "unknown command: " + name + " (try help)")
        return ctx["out"]
    cmd(ctx, args)
    return ctx["out"]

# shell_loop(ctx): prompt / read / execute until EOF or exit. Returns
# ctx["out"].
proc shell_loop(ctx):
    while true:
        var w = ctx["io"]["write"]
        w(PROMPT)
        var r = ctx["io"]["read"]
        var line = ""
        if r != nil:
            line = r()
        if line == nil:
            return ctx["out"]
        shell_run_line(ctx, line)
        if ctx["exit"]:
            return ctx["out"]