# shell/parser.sage - SageShell command line tokenizer.
#
# Splits a command line into words the way a small POSIX-ish shell does:
# whitespace separates tokens, double quotes group a single token
# (spaces inside stay), and backslash escapes the next character
# (\" \\ \  inside or outside quotes). Empty result -> [].
#
# parse_tokens(line) -> array of token strings.

proc sh_split_is_ws(c):
    return c == " " or c == "\t" or c == "\r" or c == "\n"

# parse_tokens(line): whitespace/quote/escape split. Always returns an
# array (possibly empty). Unterminated quotes are truncated silently.
proc parse_tokens(line):
    var out = []
    var cur = ""
    var inq = false
    var i = 0
    while i < len(line):
        var c = line[i]
        if c == "\\":
            i = i + 1
            if i < len(line):
                cur = cur + line[i]
        else:
            if c == "\"":
                if inq:
                    inq = false
                else:
                    inq = true
            else:
                if inq:
                    cur = cur + c
                else:
                    if sh_split_is_ws(c):
                        if cur != "":
                            push(out, cur)
                            cur = ""
                    else:
                        cur = cur + c
        i = i + 1
    if cur != "":
        push(out, cur)
    return out