# SageVM Specification

> **Version:** 0.1.0 · **Component:** sagevm/ · **Related:** [architecture.md](architecture.md)

SageVM is the portable execution layer of SagePocket. It executes Sage
bytecode produced by the Sage compiler, providing one application runtime
across the ARM build, the RISC-V build, and host platforms.

**Principle:** correctness before performance.

---

## 1. Pipeline

```text
SageLang
   ↓
Lexer
   ↓
Parser
   ↓
AST
   ↓
Compiler
   ↓
Sage Bytecode
   ↓
SageVM
```

SageVM executes the bytecode produced by the Sage compiler pipeline. The
exact bytecode encoding must be synchronized with the authoritative Sage
`bytecode.h` definitions (SageVM already maintains full opcode parity in the
upstream project — this port must stay synchronized).

## 2. VM Components

```text
bytecode loader
instruction decoder
registers
stack
heap
call stack
GC
syscalls
module loader
exception handling
debugger
```

Source layout:

```text
sagevm/
├── vm.sage           VM core: run loop, registers, state
├── bytecode.sage     Bytecode definitions, decoding
├── interpreter.sage  Instruction execution
├── memory.sage       VM memory model, limits
├── gc.sage           Garbage collection
├── syscall.sage      System call ABI
├── loader.sage       Bytecode/module loading, validation
└── jit/              JIT stages (later)
```

## 3. Bytecode

Initial instruction categories:

```text
LOAD
STORE
MOVE

ADD
SUB
MUL
DIV
MOD

AND
OR
XOR
NOT
SHL
SHR

CMP
JMP
JZ
JNZ

CALL
RET

PUSH
POP

ALLOC
FREE

LOAD_GLOBAL
STORE_GLOBAL

SYSCALL

HALT
```

The exact opcode numbering, operand encoding, and constant-pool format must
match the Sage bytecode specification (`bytecode.h` in SageLang core).

## 4. Memory Model

```text
VM
│
├── bytecode
├── constant pool
├── registers
├── operand stack
├── call stack
├── heap
└── globals
```

### 4.1 Memory Limits

VM applications have a configurable memory limit:

```text
run calculator --memory=32K
```

A hard ceiling guards the platform budget (96 KB budgeted for the VM in the
SRAM plan). Out-of-memory inside an application must raise a recoverable
fault, not crash the system.

## 5. System Call ABI

Applications talk to SageOS through syscalls issued by the VM:

```text
SYS_EXIT
SYS_OPEN
SYS_READ
SYS_WRITE
SYS_CLOSE

SYS_SLEEP
SYS_TIME

SYS_DISPLAY
SYS_INPUT

SYS_FS_STAT
SYS_FS_LIST

SYS_THREAD_CREATE

SYS_RANDOM

SYS_SYSTEM_INFO
```

Syscall dispatch is handled by the kernel (see [sageos.md](sageos.md) §5)
and enforced by the sandbox (see [security.md](security.md)).

## 6. Garbage Collection

The VM provides GC for application memory:

- Precise or conservative marking as appropriate for embedded SRAM
- Bounded pause times via incremental/partial collection
- Memory statistics exposed to the monitor and `mem`

GC budget must fit the VM memory budget while leaving headroom for the
interpreter itself. (Host SageLang immediately provides a tracing GC, ARC,
and ORC modes; the embedded VM GC is an independent implementation tailored
to the RP2350.)

## 7. Loading and Validation

`loader.sage` responsibilities:

```text
parse .sbc bytecode
validate instruction stream (bounds, jump targets, constant pool)
enforce size limits
resolve module imports (VM module loader)
```

Invalid bytecode must be rejected with a diagnostic before execution.

## 8. Exceptions and Faults

```text
application fault
    ↓
SageVM detects fault
    ↓
terminate application
    ↓
release memory
    ↓
write crash log (/logs/sagevm.log)
    ↓
return to desktop
```

See [security.md](security.md) for the full crash-recovery design.

## 9. JIT Strategy (Later)

A full JIT is not an early requirement. Staged approach:

```text
Stage 1   bytecode interpreter
Stage 2   bytecode optimizer
Stage 3   hot-block detection
Stage 4   native code cache
Stage 5   ARM JIT
Stage 6   RISC-V JIT
```

Native code only consumes RAM when worthwhile — the JIT must respect the
memory budget and never speculate arbitrarily.

## 10. Native Compilation (Later)

After the VM is stable, the same Sage source can target machine code:

```text
SageLang → Sage IR → ARM backend     → RP2350 machine code
SageLang → Sage IR → RISC-V backend  → Hazard3 machine code
SageLang → SageVM                      (portable bytecode)
```

## 11. Debugging

- VM debugger hooks (breakpoints, single step, call-stack dump)
- `sagevm` log at `/logs/sagevm.log`
- Integration with the Sage debugger tooling on the host

## 12. Definitions of Done

### SagePocket 0.4 milestone

- [ ] Bytecode loader + interpreter execute `hello.sbc` on the board
- [ ] Syscalls route to SageOS services
- [ ] Memory limits enforced
- [ ] Invalid bytecode rejected safely

Related docs: [architecture.md](architecture.md), [sageos.md](sageos.md),
[applications.md](applications.md), [security.md](security.md).