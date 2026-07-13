# Vivado

`create_project.tcl` performs batch synthesis and writes utilization and timing
reports under `synth/vivado/build`. The synthesis target uses a comprehensive
RV32IM program image and a 100 MHz clock requirement so Vivado retains the
complete single-cycle datapath and produces constrained timing results.

Before using it:

1. Replace `part_name` with the exact FPGA device on your board.
2. Keep `core_single_cycle` as the top while checking RTL synthesis.
3. Later add a board wrapper for clock/reset, BRAM, LEDs, and UART.
4. Put board pin and external I/O constraints in `constraints.xdc`.

The script reads `rtl/common/rv32i_pkg.sv` before all importing modules. Keep
this ordering when adding future pipeline or out-of-order source files.

Run from any PowerShell directory:

```powershell
$vivado = "D:\2025.2\Vivado\bin\vivado.bat"
& $vivado -mode batch `
    -source "D:\Git\ooop-riscv\synth\vivado\create_project.tcl"
```

`timing_summary.rpt` measures internal clocked paths. Pin locations and
external input/output delays remain deferred until the board wrapper exists.
