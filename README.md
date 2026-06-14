# OOOP-RISCV

OOOP-RISCV is a learning-focused SystemVerilog implementation of an RV32I
processor. The project will progress through three separately verified cores:

1. Single-cycle RV32I
2. Five-stage pipelined RV32I
3. Small out-of-order RV32I

The single-cycle core now serves as the passing reference design. The current
milestone is the five-stage pipelined core. Out-of-order hardware should not
begin until the directed pipeline regression passes.

## Tools

- Questa for RTL simulation and waveform debugging
- Vivado for synthesis, timing, utilization, and later FPGA integration

## Current Layout

```text
docs/                         Architecture decisions, roadmap, and ownership
rtl/common/                   RTL shared by both in-order cores
rtl/single_cycle/             Completed single-cycle top level
rtl/pipeline/                 Five-stage pipeline implementation
tb/unit/common/               Tests for shared RTL modules
tb/unit/pipeline/             Tests for pipeline-only modules
tb/integration/single_cycle/  Completed single-cycle integration test
tb/integration/pipeline/      Pipeline integration test
tb/programs/                  Hand-authored instruction-memory images
sim/questa/                   Questa compile and run scripts
synth/vivado/                 Vivado batch synthesis scripts
```

The completed single-cycle core is intentionally kept separate and should
remain a passing reference while `rtl/pipeline/` is developed.

## First Simulation

From `sim/questa` in a terminal:

```powershell
vsim -c -do run_unit.do
vsim -c -do run_core.do
```

Both scripts terminate with a nonzero simulation result when a test reports an
error.

## Side Quests

Optional verification, ISA, cache, branch-prediction, SoC, FPGA, performance,
and advanced architecture projects are collected in
[`docs/sidequests.md`](docs/sidequests.md). These are exploration tracks, not
requirements for the current pipeline milestone.

## Vivado Synthesis

Edit `synth/vivado/create_project.tcl` to select the FPGA part for your board,
then run:

```powershell
vivado -mode batch -source synth/vivado/create_project.tcl
```

The first synthesis target is `core_single_cycle`. Board I/O and an FPGA wrapper
will be added after the core passes simulation.

## Collaboration

Read `docs/collaboration.md` before implementing modules. Freeze ports and
shared types in `rtl/common/rv32i_pkg.sv` before parallel work begins.
