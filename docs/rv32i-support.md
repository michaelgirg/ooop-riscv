# RV32I And RV32M Support

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

## RV32M Single-Cycle Support

- `MUL`, `MULH`, `MULHSU`, `MULHU`
- `DIV`, `DIVU`, `REM`, `REMU`
- Divide by zero returns the architectural quotient or dividend remainder;
  it does not raise a trap.
- Signed overflow for `0x80000000 / 0xffffffff` returns `0x80000000`, and the
  corresponding remainder is zero.
- The single-cycle core uses combinational multiplication and division. The
  pipelined core's variable-latency RV32M integration remains separate.

## RV32M Pipeline And OOO Support

- The pipeline and OOO execution cluster reuse the multi-cycle `muldiv_unit`.
- Multiplication and division results remain valid until their consumer accepts
  them, preventing cache or result-bus backpressure from reissuing an operation.
- The OOO execution cluster retains the originating ROB and physical-register
  tags for the complete operation and suppresses a late result after recovery.
- The OOO unit regression covers normal multiply/divide completion and a
  squashed younger long-latency multiply.

## Special Instructions

- `FENCE`: NOP for the initial single-core memory model; reserved fields are
  ignored as required for forward compatibility
- `FENCE.I` (`Zifencei`): supported as a NOP; unused fields are ignored
- `ECALL` and `EBREAK`: halt simulation
- CSR instructions: unsupported initially

## Fault Policy

- Illegal instructions, misaligned control-flow targets, misaligned data
  accesses, and local-memory access faults are detected.
- The single-cycle and pipeline cores halt and expose the fault through debug
  outputs.
- The OOO core records the fault in the ROB, suppresses side effects, reports it
  at in-order retirement, flushes speculative state, and redirects to the
  external trap-vector input.
- Trap CSRs and exception-return instructions remain deferred.

The decoder must still identify unsupported encodings so the testbench can
report them rather than silently executing arbitrary behavior.
