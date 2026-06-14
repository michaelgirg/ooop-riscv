# Single-Cycle Architecture

## Fixed Decisions

- ISA: RV32I, little-endian
- XLEN: 32 bits
- Instruction width: 32 bits
- Register count: 32
- Memory addressing: byte addressed
- Reset: active-high, synchronous
- Reset PC: `0x00000000`
- Reset does not clear `x1`-`x31` or data memory
- Instruction memory: combinational read
- Data memory: combinational read, synchronous write
- Misaligned and out-of-range accesses: reported as faults
- `FENCE`: treated as a NOP
- `ECALL` and `EBREAK`: assert the core halt output

## Datapath

```text
PC -> IMEM -> Decoder -> Register File -> ALU -> DMEM -> Writeback
                     \-> Immediate Generator
                     \-> Branch/Jump Next-PC Logic
```

The single-cycle core completes one instruction between rising clock edges.
The PC and architectural register file update at the rising edge.

## Memory Contract

- Instruction and data addresses are byte addresses.
- Instructions must be aligned to four-byte boundaries (`IALIGN=32`).
- Byte accesses may use any address, halfword accesses require `addr[0]=0`, and
  word accesses require `addr[1:0]=0`.
- Data memory accepts exactly one of `mem_read` or `mem_write` per request.
- Faulting loads return zero and faulting stores do not modify memory.
- Because milestone 1 has no trap handler, an instruction or data fault freezes
  the core and is exposed through a debug output.

The register file and data memory are initialized to zero for deterministic
simulation and FPGA bring-up. Software must not rely on `x1`-`x31` being zero
after reset; only `x0` is architecturally guaranteed to read zero.

## Integration Contract

All instruction decode constants and packed control fields belong in
`rtl/rv32i_pkg.sv`. Shared interfaces must be reviewed by both contributors
before they are changed.

The core exposes a small debug interface for integration tests:

- current PC
- current instruction
- halt state
- illegal-instruction state
- instruction-access/alignment fault state
- data-access/alignment fault state

Architectural register checking should normally use hierarchical access only
inside the testbench.

## Pipeline and OOO Contract

Later cores must carry instruction validity, PC, destination register, memory
operation, and fault information with each in-flight instruction. Register and
memory side effects must be suppressed for squashed or faulting instructions.
The out-of-order core must delay architectural register writes and stores until
in-order retirement.
