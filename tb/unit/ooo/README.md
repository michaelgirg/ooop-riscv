# Mike OOO Unit Tests

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

## Questa

From `sim/questa`, compile the package, interfaces, and tests with:

```powershell
vsim -c -do "do compile_ooo_mike_unit.do; quit -code 0"
```

After the five RTL modules are implemented, run the tests with:

```powershell
vsim -c -do run_ooo_mike_unit.do
```

The current OOO modules are interface skeletons. Compilation should pass now;
functional simulations are expected to fail until their TODO bodies are
implemented.
