# Two-Person Work Split

## Person A: Datapath

- `rtl/common/alu.sv`
- `rtl/common/regfile.sv`
- `rtl/common/imm_gen.sv`
- `rtl/common/branch_unit.sv`
- load/store formatting in `rtl/common/dmem.sv`
- matching unit tests

## Person B: Control and Integration

- `rtl/common/decoder.sv`
- `rtl/common/pc.sv`
- `rtl/common/imem.sv`
- `rtl/single_cycle/core_single_cycle.sv`
- integration tests and test programs
- Questa and Vivado project maintenance

## Shared Ownership

- `rtl/common/rv32i_pkg.sv`
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
- Misaligned and out-of-range requests cannot modify architectural state.
- A multi-instruction program reaches its expected final register and memory
  state.
- Questa reports no test errors or unexpected latches.
- Vivado synthesis completes and reports timing/utilization.

## Five-Stage Pipeline Work Split

The pipeline uses the classic `IF`, `ID`, `EX`, `MEM`, and `WB` stages. Keep
`rtl/single_cycle/core_single_cycle.sv` as the passing reference design and
build the pipeline under `rtl/pipeline/`.

### Shared Design Work Before Coding

Both people should agree on the contents of the four pipeline registers before
creating modules:

- `IF/ID`: valid bit, PC, and instruction
- `ID/EX`: valid bit, PC, register operands and addresses, immediate,
  destination register, and decoded control signals
- `EX/MEM`: valid bit, ALU result, store data, destination register, memory
  controls, writeback controls, and fault information
- `MEM/WB`: valid bit, ALU result, load data, PC + 4, destination register,
  writeback controls, and fault information

Define all four payloads as packed structs in
`rtl/common/rv32i_pkg.sv` before either person writes a pipeline-register
module. This makes the package the single source of truth for field names,
widths, and ordering.

Questa 2021.2 accepts named assignment patterns such as
`'{valid: 1'b0, pc: '0, ...}` for packed structs. Icarus Verilog 12 may reject
that syntax, so only use concatenation-based bubble constants if Icarus becomes
an officially supported project tool. A concatenation depends on exact field
ordering and is easier to break when a struct changes.

Shared edits:

- `rtl/common/rv32i_pkg.sv`
- `rtl/pipeline/core_pipeline.sv`
- `tb/integration/pipeline/core_pipeline_tb.sv`
- pipeline-register interfaces and valid/stall/flush behavior
- changes to existing module ports

### Person A: Data Hazards and Execution Path

Primary goal: learn RAW hazards, bypassing, and load-use stalls.

New RTL ownership:

- `rtl/pipeline/forwarding_unit.sv`
- `rtl/pipeline/load_use_hazard_unit.sv`
- `rtl/pipeline/id_ex_reg.sv`
- `rtl/pipeline/ex_mem_reg.sv`

Verification ownership:

- `tb/unit/pipeline/forwarding_unit_tb.sv`
- `tb/unit/pipeline/load_use_hazard_unit_tb.sv`
- directed programs for ALU-to-ALU forwarding
- directed programs for load-use stalls
- directed programs for store-data forwarding

Memory-related responsibility:

- Forward values from `EX/MEM` and `MEM/WB` to ALU operands.
- Forward the newest value into store data.
- Stall one cycle when a load result is not available for the next instruction.
- Verify dependencies involving `LB`, `LH`, `LW`, and stores.

### Person B: Control Hazards and Memory/Writeback Path

Primary goal: learn pipeline control, branch recovery, and precise side-effect
control.

New RTL ownership:

- `rtl/pipeline/pipeline_control.sv`
- `rtl/pipeline/if_id_reg.sv`
- `rtl/pipeline/mem_wb_reg.sv`

Verification ownership:

- `tb/unit/pipeline/pipeline_control_tb.sv`
- directed programs for taken and not-taken branches
- directed programs for `JAL` and `JALR`
- directed programs for back-to-back loads and stores
- directed programs proving flushed instructions cannot write registers or
  memory

Memory-related responsibility:

- Connect the `MEM` stage to `dmem`.
- Carry load data and writeback selection into `MEM/WB`.
- Suppress stores from invalid, flushed, halted, or faulting instructions.
- Propagate memory faults without allowing younger instructions to commit.

### Integration Work Done Together

1. Instantiate the pipeline registers in `core_pipeline.sv` with hazard logic
   temporarily disabled.
2. Run independent instructions through all five stages.
3. Add Person A's forwarding paths.
4. Add the load-use stall and confirm that the PC and `IF/ID` register hold
   while `ID/EX` receives a bubble.
5. Add Person B's branch redirect and flush logic. A taken control transfer
   must squash younger instructions in `IF/ID` and `ID/EX`.
6. Add memory faults, halting, and illegal-instruction handling.
7. Run the full single-cycle instruction suite against the pipelined core, then
   add mixed hazard programs.

### Pipeline Definition of Done

- Independent instructions retire correctly.
- ALU dependencies work with no unnecessary stalls.
- A load-use dependency inserts exactly the required bubble.
- Store addresses and store data use the newest operand values.
- Taken branches and jumps squash all wrong-path side effects.
- `JAL` and `JALR` write the correct link address.
- Faulting or invalid instructions cannot write registers or memory.
- The pipeline drains correctly on `ECALL` or `EBREAK`.
- Unit and integration regressions pass in Questa.
- Vivado synthesis completes and timing/utilization are recorded.
