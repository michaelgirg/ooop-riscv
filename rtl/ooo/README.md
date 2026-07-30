# Single-Wide OOO RTL Scaffold

This directory starts a new out-of-order core without modifying the passing
five-stage pipeline. The first version renames, dispatches, and retires at most
one instruction per cycle. Ready instructions may still execute out of order.

Only `ooo_pkg.sv` is implemented. Every other SystemVerilog file is an
interface-and-comment skeleton for the assigned owner to complete.

## Ownership

### Mike: Rename And Retirement

1. `physical_regfile.sv`
2. `rename_map.sv`
3. `free_list.sv`
4. `rob.sv`
5. `commit_unit.sv`

### Ant: Frontend And Execution

1. `ooo_frontend.sv`
2. `rename_stage.sv`
3. `issue_queue.sv`
4. `execute_cluster.sv`
5. `result_arbiter.sv`

### Together: Memory, Recovery, And Integration

1. `memory_queue.sv`
2. `ooo_control.sv`
3. `core_ooo.sv`

The together files should not be implemented until the dependencies listed
below are passing their own module-level tests.

## Build Order And Dependencies

1. **Independent first work**
   - Mike: `physical_regfile.sv`, `rename_map.sv`, and `free_list.sv`
   - Ant: `ooo_frontend.sv` and `result_arbiter.sv`
2. **First dependent work**
   - `rob.sv` depends only on `ooo_pkg.sv`.
   - `issue_queue.sv` depends on the common result-bus and recovery contracts.
   - `execute_cluster.sv` depends on the issue request and result arbiter.
3. **Rename integration**
   - `rename_stage.sv` depends on the physical register file, rename map, free
     list, ROB allocation interface, and destination queue readiness.
4. **Retirement and memory**
   - `commit_unit.sv` depends on the ROB head interface and the store-commit
     side of `memory_queue.sv`.
   - `memory_queue.sv` depends on ROB age/head information, result arbitration,
     recovery, and the existing D-cache request/response interface.
5. **Together last**
   - `ooo_control.sv` joins branch recovery, precise traps, and redirects.
   - `core_ooo.sv` is wiring only after every block above works independently.

## Shared Rules

- A valid/ready transfer occurs only when both signals are one in the same
  cycle. The producer holds `valid` and its payload stable until accepted.
- `x0` always maps to `p0`; `p0` is always ready and always contains zero.
- A destination physical register becomes not-ready when allocated and ready
  only when its matching result is accepted on the result bus.
- A ROB completion must match the full wrapped `rob_tag_t`, not only its array
  index. This rejects late completions from squashed operations.
- Branch recovery preserves the branch and all older instructions. Only
  younger ROB, issue-queue, and memory-queue entries are removed.
- The rename-map and free-list checkpoints represent state immediately after
  the branch itself is renamed.
- A store may calculate its address and data early, but it cannot modify the
  D-cache until that store reaches the ROB head.
- An exception is recorded when detected but becomes architectural only when
  its instruction reaches the ROB head.
- The first version uses predict-not-taken and one common result bus.
