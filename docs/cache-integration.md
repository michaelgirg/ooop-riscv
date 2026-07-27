# Pipeline Cache Integration

## Implemented Organization

The five-stage pipeline now uses:

- A parameterized direct-mapped instruction cache
- A parameterized set-associative, write-back, write-allocate data cache
- Tree PLRU replacement for the data cache
- Two independent delayed line memories, one for instructions and one for data
- Four 32-bit words per cache line by default
- Fifteen-cycle backing-memory latency by default

Keeping separate instruction and data memories allows simultaneous I-cache and
D-cache misses without adding a memory arbiter during this milestone. A unified
memory controller can be added later without changing either CPU-side cache
interface.

The delayed backing memories store one complete cache line per block-RAM
entry. Pipeline HEX files therefore contain one 128-bit line per row for the
default four-word line, with the lowest-addressed word in bits `[31:0]` (the
rightmost eight hexadecimal digits). Single-cycle memories continue using one
32-bit word per row.

## Pipeline Control Rules

The control priority is:

```text
trap > D-cache/MEM stall > EX redirect > load-use > MUL/DIV > I-cache stall
```

An I-cache miss freezes only PC and IF/ID. Instructions already in ID, EX, MEM,
and WB continue draining. A redirect outranks the I-cache stall, so the PC can
capture a branch target while an obsolete wrong-path refill finishes.

A D-cache transaction freezes EX/MEM and every younger stage. The response is
first captured in MEM/WB; the held instruction is released on the following
cycle. This lets an immediately dependent instruction use the existing MEM/WB
forwarding path and prevents a held MUL/DIV operation from reissuing.

## Questa Regression

Run from the repository root:

```powershell
Set-Location .\sim\questa
vsim -c -do run_pipeline_unit.do
vsim -c -do run_pipeline_core.do
```

The core regression includes directed checks for:

- Redirect during an I-cache miss
- D-cache load/store hits and misses
- Dirty eviction and writeback
- Load-use forwarding after a cache response
- MUL/DIV completion while MEM is back-pressured
- Out-of-range instruction and data refill faults

The automated scripts use normal optimization. Add `-voptargs=+acc` manually
for interactive waveform debugging; Questa Starter 2021.2 can crash when full
signal visibility is forced on the large I-cache testbench.

## Vivado Pipeline Synthesis

Run synthesis only after both pipeline Questa commands pass.

The build targets the ZedBoard's `xc7z020clg484-1` device directly. Installing
the optional Avnet board files is not required for this RTL-only synthesis and
timing report.

From the repository root, either let the launcher find Vivado:

```powershell
powershell -ExecutionPolicy Bypass -File .\synth\vivado\run_pipeline_synth.ps1
```

Or give the launcher your installation explicitly:

```powershell
powershell -ExecutionPolicy Bypass `
  -File .\synth\vivado\run_pipeline_synth.ps1 `
  -VivadoPath "<Vivado installation>\bin\vivado.bat"
```

Without `-VivadoPath`, the launcher checks `PATH` and then the
`XILINX_VIVADO` environment variable.

The generated reports are:

```text
synth/vivado/build_pipeline/utilization.rpt
synth/vivado/build_pipeline/timing_summary.rpt
synth/vivado/build_pipeline/methodology.rpt
synth/vivado/build_pipeline/route_status.rpt
```

The synthesized checkpoint is saved before implementation. Timing is reported
after optimization, placement, physical optimization, and routing. If a later
step is interrupted, `run_pipeline_synth.ps1 -ReportsOnly` resumes from the
checkpoint and avoids repeating synthesis.

The launcher uses `synth/vivado/.vivado_user` for temporary Vivado profile data.
This prevents stale per-user app settings from breaking batch startup and keeps
the command reproducible across both development machines.

Open `timing_summary.rpt` and inspect the worst path before changing the cache.
Pipeline the I-cache hit only if the path actually crosses its data array, tag
comparison, instruction selection, and IF/ID setup. That optimization changes
fetch from a flow-through hit into a registered response, so it also requires a
request-PC register and wrong-path response cancellation.

After synthesis, print a short summary and package the reports for review:

```powershell
powershell -ExecutionPolicy Bypass `
  -File .\synth\vivado\view_pipeline_reports.ps1 `
  -Package
```

This creates `synth/vivado/pipeline_reports.zip`. Attach that archive when asking
for timing analysis so the exact worst paths, utilization, and methodology
messages can be reviewed together.
