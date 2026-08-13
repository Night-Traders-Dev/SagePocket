# tests/unit/shell.sage - SageShell parser unit test.
# expect: 3 tokens
# expect: ls /docs
# expect: a b
# expect: c
# expect: 3

import shell.parser as parser

var t1 = parser.parse_tokens("ls -la /docs")
print str(len(t1)) + " tokens"
print t1[0] + " " + t1[2]

var t2 = parser.parse_tokens("echo \"a b\" c")
print t2[1]
print t2[2]

var t3 = parser.parse_tokens("echo a\\ b c")
print str(len(t3))