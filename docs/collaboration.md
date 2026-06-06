# Two-Person Work Split

## Person A: Datapath

- `rtl/alu.sv`
- `rtl/regfile.sv`
- `rtl/imm_gen.sv`
- `rtl/branch_unit.sv`
- load/store formatting in `rtl/dmem.sv`
- matching unit tests

## Person B: Control and Integration

- `rtl/decoder.sv`
- `rtl/pc.sv`
- `rtl/imem.sv`
- `rtl/core_single_cycle.sv`
- integration tests and test programs
- Questa and Vivado project maintenance

## Shared Ownership

- `rtl/rv32i_pkg.sv`
- architectural decisions
- module port changes
- milestone acceptance

## Git Rules

1. Use one feature branch per module or test.
2. Merge only when that module's self-checking test passes.
3. Keep commits small and name the tested behavior.
4. Review each other's RTL.
5. Never change a shared port or package type without coordinating first.
6. Keep `main` passing.

## Definition of Done for Single Cycle

- `x0` always reads zero.
- Every supported instruction has a directed test.
- Signed and unsigned comparisons are correct.
- Loads sign-extend or zero-extend correctly.
- Stores apply the correct byte enables.
- Branch and jump targets are correct.
- A multi-instruction program reaches its expected final register and memory
  state.
- Questa reports no test errors or unexpected latches.
- Vivado synthesis completes and reports timing/utilization.
