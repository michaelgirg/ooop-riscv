# Pipeline Interfaces

This document freezes the behavioral contract used by the five-stage pipeline
and its verification environment. Keep these rules stable while replacing the
in-order pipeline with an out-of-order back end.

## Pipeline Payloads

The packed payload types in `rtl/common/rv32i_pkg.sv` are the source of truth
for data passed between stages. Every payload has a `valid` bit.

- `valid = 1` means the entry contains an instruction that may advance.
- `valid = 0` means the entry is a bubble and cannot create a side effect.
- A flushed, halted, illegal, or faulting instruction cannot write a register
  or memory.
- Reset and flush load the package's bubble constant into a pipeline register.
- Pipeline-register priority is reset/flush, then enable, then implicit hold.
  When enable is low, no assignment is needed because the flop keeps its value.

## Control Priority

`pipeline_control.sv` is the only owner of pipeline stall and flush outputs.
Its priority from oldest or most urgent event to youngest is:

```text
trap > D-cache/MEM stall > EX redirect > load-use > MUL/DIV > I-cache stall
```

- A taken branch or jump redirects PC and flushes both `IF/ID` and `ID/EX`.
- A load-use hazard holds PC and `IF/ID` and injects one bubble into `ID/EX`.
- A running MUL/DIV holds PC, `IF/ID`, and `ID/EX`; `EX/MEM` receives bubbles
  until the result is ready.
- A D-cache transaction holds PC through `EX/MEM`. `MEM/WB` drains normally and
  captures the response before the held memory instruction is released.
- An I-cache miss holds PC, advances the existing `IF/ID` entry once, and then
  clears `IF/ID` to a bubble. Holding `IF/ID` during the refill is forbidden
  because it would decode and issue the same instruction repeatedly.

## Cache Handshake

CPU-side cache requests remain stable while the cache is busy. A response is
consumed only when its valid/ready handshake completes.

- One accepted load request produces one load response or one fault.
- One accepted store request modifies the cache exactly once.
- A dirty victim writes one complete cache line to backing memory before refill.
- The core may release a held memory instruction only after its response has
  been captured for writeback.
- A wrong-path I-cache refill may finish, but its instruction must not enter the
  pipeline after a newer redirect.

## MUL/DIV Handshake

`muldiv_unit` accepts a new instruction only on its issue condition. While the
operation is running, ID/EX holds the same payload and no second issue pulse is
allowed. A completed result remains available until the pipeline can advance it;
MEM back-pressure must not restart or discard the operation.

## Architectural Events

The verification counters use these definitions for both the pipeline and
future architectures:

- `cycle`: one active, non-reset clock cycle
- `retire`: one valid, non-halted, non-faulting instruction commits
- `stall`: the PC is held by pipeline back-pressure
- `branch`: one valid conditional branch reaches retirement
- `redirect`: one accepted taken branch, JAL, or JALR redirect
- `cache hit`: one accepted CPU access completed by a resident line
- `cache miss`: one new line refill transaction, not each busy cycle
- `store`: one architecturally accepted store request
- `muldiv issue`: one accepted RV32M operation

## OOO Boundary

The OOO core may execute and finish instructions in any order, but architectural
register updates, stores, and faults must become visible in program order. Each
in-flight instruction needs a unique identity, validity, destination, result or
memory operation, PC, and fault state. Squashed entries cannot wake dependents,
write a register, send a store, or retire.
