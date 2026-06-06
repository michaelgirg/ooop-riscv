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

- `FENCE` and `FENCE.I`: NOP for the initial single-core memory model
- `ECALL` and `EBREAK`: halt simulation
- CSR instructions: unsupported initially

## Exceptions Deferred

- Misaligned instruction fetch
- Misaligned data access
- Access faults
- Illegal-instruction trap handler

The decoder must still identify unsupported encodings so the testbench can
report them rather than silently executing arbitrary behavior.
