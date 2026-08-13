# sagevm/caps_driver.sage - Phase 8 caps verification body (appended by
# tools/compose_sagevm.py): the arena bridge in normal vs safe mode, and
# the engine's call-depth boundary, all run through the vendored VM core.

proc pocket_sgvm_caps():
    print "== caps: normal mode =="
    let r1 = SGVMRunner()
    r1.run_file("build/sgvm_mem.sgvm", false)

    print "== caps: safe mode =="
    let r2 = SGVMRunner()
    r2.run_file("build/sgvm_mem.sgvm", false, true)

    print "== caps: depth boundary =="
    let r3 = SGVMRunner()
    r3.run_file("build/sgvm_depth.sgvm", false)

    print "== caps: syscall table =="
    let r4 = SGVMRunner()
    r4.run_file("build/sgvm_syscall.sgvm", false)

    print "== caps: syscall safe =="
    let r5 = SGVMRunner()
    r5.run_file("build/sgvm_syscall.sgvm", false, true)

    print "== caps: gc churn and arena bounds =="
    let r6 = SGVMRunner()
    r6.run_file("build/sgvm_gc.sgvm", false)

    print "caps done"

pocket_sgvm_caps()