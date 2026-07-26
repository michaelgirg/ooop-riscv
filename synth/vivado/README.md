# Vivado

`create_project.tcl` performs single-cycle batch synthesis and writes reports
under `synth/vivado/build`. The synthesis target uses a comprehensive
RV32IM program image and a 100 MHz clock requirement so Vivado retains the
complete single-cycle datapath and produces constrained timing results.

Both synthesis targets are configured for the ZedBoard device:

```text
xc7z020clg484-1
```

The scripts target the FPGA part directly, so the optional Avnet Vivado board
files are not required for RTL synthesis. Before using them:

1. Keep `core_single_cycle` as the top while checking single-cycle RTL.
2. Use `core_pipeline` for the cached pipeline timing build.
3. Later add a board wrapper for clock/reset, BRAM, LEDs, and UART.
4. Put ZedBoard pin and external I/O constraints in `constraints.xdc`.

The script reads `rtl/common/rv32i_pkg.sv` before all importing modules. Keep
this ordering when adding future pipeline or out-of-order source files.

Run the single-cycle target from the repository root when Vivado is on `PATH`:

```powershell
vivado -mode batch -source .\synth\vivado\create_project.tcl
```

`timing_summary.rpt` measures internal clocked paths. Pin locations and
external input/output delays remain deferred until the board wrapper exists.

## Cached Pipeline

After the pipeline Questa regression passes, run the cached pipeline target:

```powershell
powershell -ExecutionPolicy Bypass -File .\synth\vivado\run_pipeline_synth.ps1
```

The launcher checks `-VivadoPath`, `PATH`, and `XILINX_VIVADO`, in that order.
For a custom installation, pass
`-VivadoPath "<Vivado installation>\bin\vivado.bat"`. Pipeline reports are
written under `synth/vivado/build_pipeline`. See `docs/cache-integration.md`
for the complete verification and timing workflow.

Summarize and package the completed reports with:

```powershell
powershell -ExecutionPolicy Bypass -File .\synth\vivado\view_pipeline_reports.ps1 -Package
```

The full build saves `post_synth.dcp`, then runs optimization, placement,
physical optimization, and routing before timing analysis. If Vivado is
interrupted after the synthesis checkpoint is written, resume implementation
and regenerate the reports with:

```powershell
powershell -ExecutionPolicy Bypass `
  -File .\synth\vivado\run_pipeline_synth.ps1 `
  -ReportsOnly
```

Timing in `timing_summary.rpt` is post-route timing. The implemented design is
saved as `post_route.dcp`, and `route_status.rpt` confirms routing completion.
