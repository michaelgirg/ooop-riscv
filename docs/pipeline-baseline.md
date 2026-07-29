# Pipeline Baseline

## Frozen Checkpoint

The last timing-closed five-stage pipeline is preserved by the local annotated
Git tag `pipeline-100mhz-baseline` at commit `2ca51d5`.

ZedBoard post-route result for `xc7z020clg484-1`:

```text
Clock target: 100 MHz (10.000 ns)
WNS:          +0.094 ns
TNS:           0.000 ns
LUTs:          4,373
Registers:     6,748
BRAM36:        4
DSPs:          4
```

The tag preserves the exact timing result. The pre-OOO verification additions
and the I-cache replay correction are later working-tree changes.

## Final Pre-OOO Candidate

The post-fix candidate was implemented and routed on July 28, 2026 using Vivado
2025.2. It passes both pipeline regressions and closes timing with:

```text
Clock target:     100 MHz (10.000 ns)
WNS:              +0.011 ns
TNS:               0.000 ns
Failing endpoints: 0
LUTs:              4,350
Registers:         6,748
BRAM36:            4
DSPs:              4
Routing errors:    0
Critical warnings: 0
```

The remaining methodology warnings are expected for this RTL-only target: 69
missing board-level I/O delay warnings, four BRAM timing advisories, and four
wide-multiplier advisories. The candidate still needs a commit and a final
annotated tag before it becomes the shared immutable OOO starting point.

## Required Regression

Run from `sim/questa`:

```powershell
vsim -c -do run_pipeline_unit.do
vsim -c -do run_pipeline_core.do
```

The core regression covers:

- Directed RV32I arithmetic, load/store, branch, JAL, and JALR behavior
- Every RV32M operation and arithmetic corner cases
- Redirects that overlap instruction-cache misses
- Data-cache hit, miss, dirty eviction, and refill-fault behavior
- Load-use forwarding after delayed memory
- MUL/DIV completion during data-memory back-pressure
- Differential comparison of all registers and coherent memory against the
  single-cycle RV32IM reference
- Exactly one request, response, and retirement for every directed store
- Exactly one issue and retirement for every directed MUL/DIV instruction
- Cycle, retirement, stall, branch, redirect, cache, store, and MUL/DIV counts

## Readiness Rule

Do not begin OOO integration from an unverified moving target. The pre-OOO
baseline is ready only when both pipeline regressions pass, Vivado still meets
100 MHz after the control fix, and the final commit receives a new annotated
tag. Push the baseline tag only when both teammates agree that checkpoint is
the shared starting point.
