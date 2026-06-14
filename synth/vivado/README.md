# Vivado

`create_project.tcl` performs batch synthesis and writes utilization and timing
reports under `synth/vivado/build`.

Before using it:

1. Replace `part_name` with the exact FPGA device on your board.
2. Keep `core_single_cycle` as the top while checking RTL synthesis.
3. Later add a board wrapper for clock/reset, BRAM, LEDs, and UART.
4. Put board pin and clock constraints in `constraints.xdc`.

The script reads `rtl/common/rv32i_pkg.sv` before all importing modules. Keep
this ordering when adding future pipeline or out-of-order source files.

Run from the repository root:

```powershell
vivado -mode batch -source synth/vivado/create_project.tcl
```
