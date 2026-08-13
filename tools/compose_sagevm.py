#!/usr/bin/env python3
"""Compose the vendored SageVM standalone into a pocket-runnable artifact.

The upstream sagevm_standalone.sage is kept pristine in sagevm/sagevm.sage
for parity with the upstream repo. Running it under the pocket `sage`
interpreter (instead of the compiled `sagevm` binary) needs three seams,
applied here to the composed COPY only:

  1. strip the trailing auto-run tail (``import sys`` + ``main()``) -
     under the interpreter sys.args()[1] is the script path, so the
     upstream CLI would print "Unknown command" and exit
  2. ``var metal_vm = sgvm_vm.MetalVM()`` -> ``MetalVM()`` -
     ``sgvm_vm`` is a host-registered module name that only exists in
     the compiled binary; the class lives in this file
  3. ``host_thread.lock/unlock(g_gil)`` -> pocket_gil_*() no-ops -
     the GIL guards multithreaded execution; the pocket interpreter is
     single-threaded and its thread module has no matching mutex API
  4. ``run_file`` reads its input via ``io.readbytes(input_file)`` (host
     path); the pocket's payloads live on a SageFS volume, so the read is
     routed through ``pocket_load_override`` - when the runner's
     ``pocket_bytes`` attribute is set (see sagevm/loader.sage) those
     bytes are handed to the VM instead (default still hosts-read)
  5. the delegation bridge calls host ``sys.call(callee, args...)`` which
     does not exist under the pocket interpreter (guest math.abs and any
     host-proc module entry would return nil); the argc chain is
     replaced by the pocket dispatcher ``pocket_host_call``
  6. the SVM ``OP_IMPORT`` handler gains a ``sageos`` module branch - the
     pocket syscall table (guest -> SageOS services, cap-tiered by the
     engine's safe_mode via the ``safe`` argument)
  7. the callee-type check accepts the pocket interpreter's ``"native"``
     type (upstream only knows "function"/"native fn" from its own runtime)

Usage:
    tools/compose_sagevm.py [-o out.sage] [--with-driver sagevm/pocket_driver.sage]
"""

from __future__ import annotations

import argparse
import sys

SEAMS = [
    ("var metal_vm = sgvm_vm.MetalVM()", "var metal_vm = MetalVM()"),
    ("host_thread.lock(g_gil)", "pocket_gil_lock()"),
    ("host_thread.unlock(g_gil)", "pocket_gil_unlock()"),
    (
        "elif type(callee) == \"function\" or type(callee) == \"native fn\":",
        "elif type(callee) == \"function\" or type(callee) == \"native fn\" or type(callee) == \"native\":",
    ),
    (
        "if argc == 0: push(self.stack, sys.call(callee))\n"
        "                    elif argc == 1: push(self.stack, sys.call(callee, args[0]))\n"
        "                    elif argc == 2: push(self.stack, sys.call(callee, args[0], args[1]))\n"
        "                    elif argc == 3: push(self.stack, sys.call(callee, args[0], args[1], args[2]))\n"
        "                    elif argc == 4: push(self.stack, sys.call(callee, args[0], args[1], args[2], args[3]))\n"
        "                    elif argc == 5: push(self.stack, sys.call(callee, args[0], args[1], args[2], args[3], args[4]))\n"
        "                    elif argc == 6: push(self.stack, sys.call(callee, args[0], args[1], args[2], args[3], args[4], args[5]))\n"
        "                    elif argc == 7: push(self.stack, sys.call(callee, args[0], args[1], args[2], args[3], args[4], args[5], args[6]))\n"
        "                    elif argc == 8: push(self.stack, sys.call(callee, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]))\n"
        "                    else:\n"
        "                        print \"Error: Host call with >8 args not implemented\"\n"
        "                        push(self.stack, nil)",
        "                    push(self.stack, pocket_host_call(callee, args, argc))",
    ),
    (
        '                    if type(val) == "function" or type(val) == "native fn":\n                        if argc == 0: push(self.stack, sys.call(val))\n                        elif argc == 1: push(self.stack, sys.call(val, args[0]))\n                        elif argc == 2: push(self.stack, sys.call(val, args[0], args[1]))\n                        elif argc == 3: push(self.stack, sys.call(val, args[0], args[1], args[2]))\n                        elif argc == 4: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3]))\n                        elif argc == 5: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4]))\n                        elif argc == 6: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5]))\n                        elif argc == 7: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5], args[6]))\n                        elif argc == 8: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]))\n                        else:\n                            print "Error: Host module call with >8 args not implemented"\n                            push(self.stack, nil)',
        '                    if self.safe_mode:\n                        print "Error: Direct host function call is restricted in safe mode"\n                        push(self.stack, nil)\n                    elif type(val) == "function" or type(val) == "native fn" or type(val) == "native":\n                        push(self.stack, pocket_host_call(val, args, argc))',
    ),
    (
        '                    if type(val) == "function" or type(val) == "native fn":\n                        if argc == 0: push(self.stack, sys.call(val))\n                        elif argc == 1: push(self.stack, sys.call(val, args[0]))\n                        elif argc == 2: push(self.stack, sys.call(val, args[0], args[1]))\n                        elif argc == 3: push(self.stack, sys.call(val, args[0], args[1], args[2]))\n                        elif argc == 4: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3]))\n                        elif argc == 5: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4]))\n                        elif argc == 6: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5]))\n                        elif argc == 7: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5], args[6]))\n                        elif argc == 8: push(self.stack, sys.call(val, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]))\n                        else:\n                            print "Error: Host method call with >8 args not implemented"\n                            push(self.stack, nil)',
        '                    if self.safe_mode:\n                        print "Error: Direct host function call is restricted in safe mode"\n                        push(self.stack, nil)\n                    elif type(val) == "function" or type(val) == "native fn" or type(val) == "native":\n                        push(self.stack, pocket_host_call(val, args, argc))',
    ),
    (
        "proc run_file(self, input_file, debug, safe_mode=false, ffi_enabled=true, user_args=nil):\n"
        "        var data = io.readbytes(input_file)",
        "proc run_file(self, input_file, debug, safe_mode=false, ffi_enabled=true, user_args=nil):\n"
        "        var data = pocket_load_override(self, input_file)",
    ),
    (
        "                try:\n"
        "                    if name == \"math\":",
        "                try:\n"
        "                    if name == \"sageos\":\n"
        "                        push(self.stack, pocket_sageos_module(self.safe_mode))\n"
        "                    elif name == \"math\":",
    ),
]

GIL_SHIMS = (
    "\nproc pocket_gil_lock():\n    var unused = 0\n\n"
    "proc pocket_gil_unlock():\n    var unused = 0\n"
)

BYTES_OVERRIDE_SHIM = (
    "\nproc pocket_load_override(self, input_file):\n"
    "    try:\n"
    "        let b = self.pocket_bytes\n"
    "    catch e:\n"
    "        self.pocket_bytes = nil\n"
    "        let b = nil\n"
    "    if b != nil:\n"
    "        self.pocket_bytes = nil\n"
    "        return b\n"
    "    return io.readbytes(input_file)\n"
)


# The pocket host-call dispatcher replaces the engine's sys.call bridge
# (absent under the pocket interpreter). Errors are contained so a bad
# host call degrades to nil instead of crashing the VM.
HOST_CALL_SHIM = (
    "\nproc pocket_host_call(callee, args, argc):\n"
    "    try:\n"
    "        if argc == 0:\n"
    "            return callee()\n"
    "        elif argc == 1:\n"
    "            return callee(args[0])\n"
    "        elif argc == 2:\n"
    "            return callee(args[0], args[1])\n"
    "        elif argc == 3:\n"
    "            return callee(args[0], args[1], args[2])\n"
    "        elif argc == 4:\n"
    "            return callee(args[0], args[1], args[2], args[3])\n"
    "        elif argc == 5:\n"
    "            return callee(args[0], args[1], args[2], args[3], args[4])\n"
    "        elif argc == 6:\n"
    "            return callee(args[0], args[1], args[2], args[3], args[4], args[5])\n"
    "        elif argc == 7:\n"
    "            return callee(args[0], args[1], args[2], args[3], args[4], args[5], args[6])\n"
    "        elif argc == 8:\n"
    "            return callee(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])\n"
    "        else:\n"
    "            print \"Error: Host call with >8 args not implemented\"\n"
    "            return nil\n"
    "    catch e:\n"
    "        print \"pocket host call error: \" + str(e)\n"
    "        return nil\n"
)

# sageos: the pocket syscall table (guest -> SageOS services). Entries
# are host procs the engine delegates to; capability tiers follow the
# engine's safe_mode. mounts() reaches the real SageFS VFS.
SAGEOS_SHIMS = (
    "\nimport sagefs.vfs as vfs\n"
    "\n"
    "proc pocket_syscall_version():\n"
    "    return \"sagepocket 0.2.0\"\n"
    "\n"
    "proc pocket_syscall_uptime():\n"
    "    return 1337\n"
    "\n"
    "proc pocket_syscall_mounts():\n"
    "    var m = vfs.vfs_mount_info()\n"
    "    return len(m)\n"
    "\n"
    "proc pocket_syscall_disk_free():\n"
    "    return 134217728\n"
    "\n"
    "proc pocket_syscall_power(name):\n"
    "    if name == \"shutdown\":\n"
    "        return \"ok\"\n"
    "    return \"unknown\"\n"
    "\n"
    "proc pocket_sageos_module(safe):\n"
    "    var m = {}\n"
    "    m[\"__type__\"] = \"module\"\n"
    "    m[\"version\"] = pocket_syscall_version\n"
    "    m[\"uptime_ms\"] = pocket_syscall_uptime\n"
    "    m[\"power\"] = pocket_syscall_power\n"
    "    if not safe:\n"
    "        m[\"mounts\"] = pocket_syscall_mounts\n"
    "        m[\"disk_free\"] = pocket_syscall_disk_free\n"
    "    return m\n"
)



def compose(vendored: str, driver: str | None = None) -> str:
    idx = vendored.rfind("\nimport sys\n")
    assert idx > 0, "vendor auto-run tail marker not found"
    core = vendored[:idx].rstrip("\n ") + "\n"
    for old, new in SEAMS:
        assert core.count(old) == 1, f"seam not found exactly once: {old!r}"
        core = core.replace(old, new)
    out = core + GIL_SHIMS + BYTES_OVERRIDE_SHIM + HOST_CALL_SHIM + SAGEOS_SHIMS
    if driver:
        out += driver
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-o", "--output", default=None, help="output file")
    ap.add_argument("--with-driver", default=None, help="driver body to append")
    args = ap.parse_args()

    vendored = open("sagevm/sagevm.sage", encoding="utf-8").read()
    driver = None
    if args.with_driver:
        driver = open(args.with_driver, encoding="utf-8").read()
    out = compose(vendored, driver)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(out)
    else:
        sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())