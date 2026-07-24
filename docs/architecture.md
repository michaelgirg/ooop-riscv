# Architecture

## Fixed Project Decisions

- ISA: RV32I base integer ISA
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
is kept as the simple reference design for the pipelined core.

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
- An I-cache miss holds only PC and `IF/ID`, allowing older stages to drain.
- A D-cache request holds `EX/MEM` and younger stages until its response is captured in `MEM/WB`.
- Redirects outrank I-cache stalls so branch targets are not lost during a refill.

## Memory Contract

- Instruction and data addresses are byte addresses.
- Instructions must be aligned to four-byte boundaries (`IALIGN=32`).
- Byte accesses may use any address, halfword accesses require `addr[0]=0`, and word accesses require `addr[1:0]=0`.
- Data memory accepts exactly one of `mem_read` or `mem_write` per request.
- Faulting loads return zero and faulting stores do not modify memory.
- Pipeline backing memories transfer complete cache lines with valid/ready handshakes.
- The pipeline I-cache is direct mapped; the D-cache is set associative, write back, and write allocate.
- Because the current cores have no trap handler, faults halt the core and are exposed through debug outputs.

## Integration Contract

All instruction decode constants and packed pipeline payloads belong in
`rtl/common/rv32i_pkg.sv`. Shared interfaces must be reviewed by both
contributors before they are changed.

The cores expose a small debug interface for integration tests:

- current PC
- current instruction
- halt state
- illegal-instruction state
- instruction-access/alignment fault state
- data-access/alignment fault state

Architectural register checking should normally use hierarchical access only
inside testbenches.

## Pipeline and OOO Contract

Later cores must carry instruction validity, PC, destination register, memory
operation, and fault information with each in-flight instruction. Register and
memory side effects must be suppressed for squashed or faulting instructions.
The out-of-order core must delay architectural register writes and stores until
in-order retirement.
