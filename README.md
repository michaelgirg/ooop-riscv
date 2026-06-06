# OOOP-RISCV

OOOP-RISCV is a learning-focused SystemVerilog implementation of an RV32I
processor. The project will progress through three separately verified cores:

1. Single-cycle RV32I
2. Five-stage pipelined RV32I
3. Small out-of-order RV32I

The current milestone is a correct single-cycle core. Pipelining and
out-of-order hardware should not begin until the directed single-cycle
regression passes.

## Tools

- Questa for RTL simulation and waveform debugging
- Vivado for synthesis, timing, utilization, and later FPGA integration

## Current Layout

```text
docs/          Architecture decisions, supported ISA, roadmap, and ownership
rtl/           Synthesizable SystemVerilog
tb/unit/       Self-checking module tests
tb/integration/Full-core tests
tb/programs/   Hand-authored instruction-memory images
sim/questa/    Questa compile and run scripts
synth/vivado/  Vivado batch synthesis scripts
```

## First Simulation

From a Questa command prompt:

```tcl
cd sim/questa
do run_unit.do
do run_core.do
```

Both scripts terminate with a nonzero simulation result when a test reports an
error.

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
shared types in `rtl/rv32i_pkg.sv` before parallel work begins.
