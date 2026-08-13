# sagevm/pocket_driver.sage - pocket driver body for the composed VM.
#
# Appended by tools/compose_sagevm.py after the vendored core. The upstream
# CLI entry (auto-run tail) is stripped by the compose tool; this body drives
# the core directly, bypassing the sys.args()[1] = script-path CLI quirk.
# Bytecode is produced by the self-hosting `sagevm compile` (the installed
# sagevm binary emits a format its own engine parses; the outer `sage
# --sgvm` emission is NOT used - see docs/reuse.md for the drift note).

proc pocket_sgvm_demo():
    let cli = SGVMCLI()
    let src = "tests/fixtures/sgvm_demo.sage"
    let out = "build/sgvm_demo.sgvm"
    var ok = cli.verify_input(src, true)
    if ok == nil:
        print "demo failed: fixture missing"
        return
    cli.handle_compile(["sagevm", "compile", src, out], 2)
    cli.handle_run(["sagevm", "run", out], 2)
    print "sgvm demo done"

pocket_sgvm_demo()