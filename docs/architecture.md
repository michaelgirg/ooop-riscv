# Single-Cycle Architecture

## Fixed Decisions

- ISA: RV32I, little-endian
- XLEN: 32 bits
- Instruction width: 32 bits
- Register count: 32
- Memory addressing: byte addressed
- Reset: active-high, synchronous
- Reset PC: `0x00000000`
- Instruction memory: combinational read
- Data memory: combinational read, synchronous write
- Misaligned accesses: unsupported in milestone 1
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

## Integration Contract

All instruction decode constants and packed control fields belong in
`rtl/rv32i_pkg.sv`. Shared interfaces must be reviewed by both contributors
before they are changed.

The core exposes a small debug interface for integration tests:

- current PC
- current instruction
- halt state

Architectural register checking should normally use hierarchical access only
inside the testbench.
