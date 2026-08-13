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
]

GIL_SHIMS = (
    "\nproc pocket_gil_lock():\n    var unused = 0\n\n"
    "proc pocket_gil_unlock():\n    var unused = 0\n"
)


def compose(vendored: str, driver: str | None = None) -> str:
    idx = vendored.rfind("\nimport sys\n")
    assert idx > 0, "vendor auto-run tail marker not found"
    core = vendored[:idx].rstrip("\n ") + "\n"
    for old, new in SEAMS:
        assert core.count(old) == 1, f"seam not found exactly once: {old!r}"
        core = core.replace(old, new)
    out = core + GIL_SHIMS
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