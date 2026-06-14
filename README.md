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

From `sim/questa` in a terminal:

```powershell
vsim -c -do run_unit.do
vsim -c -do run_core.do
```

Both scripts terminate with a nonzero simulation result when a test reports an
error.

## Optional Side Quest: Standard RV32I Tests

After the directed regression passes, the core can be connected to a
standardized RISC-V instruction-test suite for broader ISA coverage.

- Start with the legacy `riscv-tests` `rv32ui` suite.
- Add a RISC-V GNU toolchain and an ELF-to-hex conversion script.
- Provide a linker script matching the core's instruction and data memories.
- Adapt the testbench to detect pass/fail at `EBREAK` and enforce a timeout.
- Later, consider the newer `riscv-arch-test` ACT4 framework for architectural
  certification testing.

This is an optional verification extension, not a prerequisite for beginning
the pipelined core.

## Optional Side Quest: Architecture and PPA

Once the integer cores are stable, the project can expand in one of several
directions:

- **Higher frequency:** use synthesis timing reports to identify critical paths,
  add or rebalance pipeline stages, and compare maximum clock frequency.
- **Area and power:** measure FPGA resource use and power estimates, then explore
  smaller queues, shared execution units, clock enables, and memory inference.
- **Floating point:** add the RISC-V `F` extension, including floating-point
  registers, execution units, decode, rounding modes, and verification.
- **RV64:** widen the datapath and architectural state to 64 bits, then implement
  RV64I instructions and the required 32-bit word operations.
- **Larger microarchitecture:** increase issue width, ROB and reservation-station
  capacity, execution units, and load/store resources while measuring the
  resulting performance and hardware cost.

Each track should begin from a passing baseline and record frequency, area,
power, and test results before and after the change.

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
