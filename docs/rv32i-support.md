# RV32I Support

## Milestone 1A

- `LUI`, `AUIPC`
- `JAL`, `JALR`
- `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- `LB`, `LH`, `LW`, `LBU`, `LHU`
- `SB`, `SH`, `SW`
- `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`
- `SLLI`, `SRLI`, `SRAI`
- `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`
- `XOR`, `SRL`, `SRA`, `OR`, `AND`

## Special Instructions

- `FENCE`: NOP for the initial single-core memory model; reserved fields are
  ignored as required for forward compatibility
- `FENCE.I` (`Zifencei`): supported as a NOP; unused fields are ignored
- `ECALL` and `EBREAK`: halt simulation
- CSR instructions: unsupported initially

## Fault Policy

- Illegal instructions, misaligned control-flow targets, misaligned data
  accesses, and local-memory access faults are detected.
- The single-cycle core freezes and exposes the fault through debug outputs.
- Trap CSRs, trap-vector redirection, and exception-return instructions are
  deferred.

The decoder must still identify unsupported encodings so the testbench can
report them rather than silently executing arbitrary behavior.
