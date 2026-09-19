# Architecture

## Fixed Project Decisions

- ISA: RV32IM (`RV32I` base integer ISA plus the `M` extension)
- XLEN: 32 bits
- Instruction width: 32 bits
- Register count: 32 architectural registers
- Memory addressing: byte addressed, little-endian
- Reset PC: `0x00000000`
- Single-cycle memories: combinational instruction/data reads and synchronous writes
- Pipeline memories: cached, full-line, variable-latency accesses
- Misaligned and out-of-range accesses: reported as faults
- `FENCE` and `FENCE.I`: treated as NOPs in the current local-memory model
- `ECALL` and `EBREAK`: halt the simulation core

The register file and data memory are initialized to zero for deterministic
simulation and FPGA bring-up. Software must not rely on `x1`-`x31` being zero
after reset; only `x0` is architecturally guaranteed to read zero.

## Single-Cycle Core

```text
PC -> IMEM -> Decoder -> Register File -> ALU -> DMEM -> Writeback
                     \-> Immediate Generator
                     \-> Branch/Jump Next-PC Logic
```

The single-cycle core completes one instruction between rising clock edges. It
is kept as the simple architectural reference for the pipeline and OOO cores.

## Five-Stage Pipeline

```text
IF -> IF/ID -> ID -> ID/EX -> EX -> EX/MEM -> MEM -> MEM/WB -> WB
```

Stage roles:

- `IF`: fetch instruction at the current PC
- `ID`: decode, generate immediates, and read the register file
- `EX`: ALU work, branch compare, and branch/jump target calculation
- `MEM`: data-memory read/write
- `WB`: write architectural register results

Pipeline safety rules:

- Every pipeline-register payload carries a `valid` bit.
- A bubble is represented by a payload with `valid = 0` and cleared controls.
- Invalid, flushed, halted, or faulting instructions must not write registers or memory.
- ALU results can forward from `EX/MEM` or `MEM/WB` into EX.
- Load-use hazards stall PC and `IF/ID` for one cycle and inject one bubble into `ID/EX`.
- Branches and jumps are resolved in EX with predict-not-taken behavior, so taken redirects flush `IF/ID` and `ID/EX`.
- A same-cycle WB-to-ID bypass lets Decode see a value being written back on the same clock cycle.
- An I-cache miss holds the PC while the current `IF/ID` instruction advances once; `IF/ID` is then cleared to a bubble while the refill finishes.
- A D-cache request holds `EX/MEM` and younger stages until its response is captured in `MEM/WB`.
- Redirects outrank I-cache stalls so branch targets are not lost during a refill.

## Single-Wide Out-of-Order Core

```text
Fetch/Decode -> Rename -> ROB + Issue/Memory Queues -> Execute/Memory
                    ^                    |                    |
                    |                    +<- Result Bus <-----+
                    +<- Commit/Recovery <- ROB Head
```

The first OOO implementation accepts and retires at most one instruction per
cycle. Independent ready instructions may issue and complete out of order.

- The speculative rename map supplies source physical registers and receives a
  new destination from the free list.
- The physical register file tracks value readiness; accepted result-bus
  broadcasts write values and wake matching queue operands.
- The issue queue selects the oldest ready ALU, branch, jump, or RV32M operation.
- The generation-tagged ROB accepts out-of-order completions and retires only
  its complete head entry.
- Predict-not-taken branches resolve in the execution cluster. A misprediction
  restores the branch's rename/free-list checkpoints and removes younger work.
- Loads access the D-cache only at the ROB head. Stores calculate their address
  early but reach the D-cache only after commit authorization.
- Traps and halt flush speculative state. The committed rename map is the
  recovery point for precise exceptions.
- A single fair result arbiter merges execution and load/store completions.

## Memory Contract

- Instruction and data addresses are byte addresses.
- Instructions must be aligned to four-byte boundaries (`IALIGN=32`).
- Byte accesses may use any address, halfword accesses require `addr[0]=0`, and word accesses require `addr[1:0]=0`.
- Data memory accepts exactly one of `mem_read` or `mem_write` per request.
- Faulting loads return zero and faulting stores do not modify memory.
- Pipeline backing memories transfer complete cache lines with valid/ready handshakes.
- The pipeline I-cache is direct mapped; the D-cache is set associative, write back, and write allocate.
- The single-cycle and pipeline cores halt on faults. The OOO core reports a
  precise retirement exception and redirects to its external trap-vector input;
  machine CSRs and `mret` are not implemented yet.

## Integration Contract

Instruction decode constants and packed pipeline payloads belong in
`rtl/common/rv32i_pkg.sv`. OOO identities, queue payloads, completion records,
ROB entries, recovery events, and retirement events belong in
`rtl/ooo/ooo_pkg.sv`. Shared interfaces must be reviewed by both contributors
before they are changed.

The cores expose a small debug interface for integration tests:

- current PC
- current instruction
- halt state
- illegal-instruction state
- instruction-access/alignment fault state
- data-access/alignment fault state
- OOO retirement event with PC, instruction, register/store side effects, and
  exception metadata

Architectural register checking should normally use hierarchical access only
inside testbenches.

## Pipeline and OOO Contract

Both non-single-cycle cores carry validity, PC, destination, memory operation,
and fault information with every in-flight instruction. Squashed or faulting
instructions cannot create register or memory side effects.

The OOO core additionally uses a complete position-plus-generation ROB tag as
the instruction identity. A completion must match that full tag, preventing a
late response from a squashed operation from completing a reused slot. Register
map updates, stale-register releases, stores, exceptions, and halt become
architectural only at in-order retirement.
