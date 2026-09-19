# Single-Wide OOO Tests

These are self-checking procedural Questa testbenches. They use `$error`,
error counters, randomized stimulus, and shadow reference models; they do not
use SVA or require an assertion license.

## Coverage

- `physical_regfile_tb.sv`: reset state, allocation/readiness, writeback,
  same-cycle priority, p0 protection, and randomized shadow-model checking.
- `rename_map_tb.sv`: speculative and committed maps, x0 protection,
  checkpoint recovery, precise-trap restore, simultaneous rename/commit, and
  randomized map/checkpoint checking.
- `free_list_tb.sv`: initial free registers, valid/ready backpressure,
  release, checkpoint recovery, committed-state rebuild, duplicate detection,
  and randomized queue checking.
- `rob_tb.sv`: allocation, full/empty behavior, out-of-order completion,
  in-order retirement, backpressure, exceptions, wraparound generations,
  selective recovery, and rejection of late stale completions.
- `commit_unit_tb.sv`: register and no-destination retirement, store waiting,
  store faults, recorded exceptions, precise side-effect suppression, and
  EBREAK halt behavior.
- `ooo_frontend_tb.sv`: request holding, decode, backpressure, and redirect.
- `rename_stage_tb.sv`: source mapping, destination allocation, and atomic
  dispatch side effects.
- `issue_queue_tb.sv`: out-of-order ready selection, result wakeup, recovery,
  and full flush.
- `execute_cluster_tb.sv`: ALU, branch recovery metadata, MUL, and squash.
- `memory_queue_tb.sv`: address completion, head-only loads, authorized stores,
  cache response handling, and misalignment.
- `result_arbiter_tb.sv`: backpressure and fair collision arbitration.
- `ooo_control_tb.sv`: branch redirects, trap priority, flush, and sticky halt.
- `core_ooo_tb.sv`: full-core RV32IM dependency, memory-ordering, branch-squash,
  exactly-once store, architectural-result, and EBREAK integration test.

## Questa

From `sim/questa`, compile and run the complete single-wide OOO suite with:

```powershell
vsim -c -do run_ooo.do
```

The script rebuilds its generated library and exits nonzero on a reported
error. It uses no SVA features and works with Questa Starter Edition.
