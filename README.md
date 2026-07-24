# OOOP-RISCV

OOOP-RISCV is a learning-focused SystemVerilog implementation of an RV32I
processor. The single-cycle reference core also implements the RV32M
multiply/divide extension. The project is built as separately verified cores:

1. Single-cycle RV32IM
2. Five-stage pipelined RV32I
3. Small out-of-order RV32I

The single-cycle RV32IM core is the passing reference design. The five-stage
pipeline now integrates RV32M, separate instruction and data caches, delayed
line memories, and directed cache/stall overlap verification in Questa.

## Tools

- Questa for RTL simulation and waveform debugging
- Vivado for synthesis, timing, utilization, and later FPGA integration

## Current Layout

```text
docs/                         Architecture decisions, roadmap, and ownership
rtl/common/                   RTL shared by the single-cycle and pipeline cores
rtl/single_cycle/             Completed single-cycle top level
rtl/pipeline/                 Five-stage pipeline RTL and top level
tb/unit/common/               Tests for shared RTL modules
tb/unit/single_cycle/         Tests for single-cycle-only execution units
tb/unit/pipeline/             Tests for pipeline-only modules
tb/integration/single_cycle/  Single-cycle integration test
tb/integration/pipeline/      Pipeline integration smoke test
tb/programs/                  Hand-authored instruction-memory images
sim/questa/                   Questa compile and run scripts
synth/vivado/                 Vivado batch synthesis scripts
```

Generated Questa libraries such as `work/`, `*_work/`, `transcript`, and
`modelsim.ini` are ignored and should not be committed.

## Simulation

Run these from `sim/questa` in a terminal.

```powershell
vsim -c -do run_unit.do
vsim -c -do run_core.do
vsim -c -do run_pipeline_unit.do
vsim -c -do run_pipeline_core.do
```

The first two commands test the shared RTL and single-cycle reference core. The
last two commands test the pipeline modules and the pipelined top-level smoke
program. Each script exits with a nonzero result when a test reports an error.

## Current Verification Status

- Shared/common unit tests: passing
- Single-cycle RV32M arithmetic unit test: passing
- Single-cycle RV32I and RV32M integration tests: passing
- Pipeline unit tests: passing
- Pipeline integration smoke test: passing
- Cached pipeline overlap and fault tests: passing
- Vivado synthesis/timing: still to be recorded

## Side Quests

Optional verification, ISA, cache, branch-prediction, SoC, FPGA, performance,
and advanced architecture projects are collected in
[`docs/sidequests.md`](docs/sidequests.md). These are exploration tracks, not
requirements for the current pipeline milestone.

## Vivado Synthesis

The Vivado scripts target the ZedBoard's `xc7z020clg484-1` device. Run the
single-cycle target with:

```powershell
vivado -mode batch -source synth/vivado/create_project.tcl
```

The single-cycle target remains `create_project.tcl`. The cached pipeline target
is `create_pipeline_project.tcl`; run it through
`synth/vivado/run_pipeline_synth.ps1` after both pipeline regressions pass.

## Collaboration

Read `docs/collaboration.md` before implementing modules. Freeze ports and
shared types in `rtl/common/rv32i_pkg.sv` before parallel work begins.
