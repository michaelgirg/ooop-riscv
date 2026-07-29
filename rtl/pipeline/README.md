# Pipeline RTL

This directory contains the five-stage pipelined RV32IM core.

## Files

- `core_pipeline.sv`: shared five-stage top-level integration
- `if_id_reg.sv`: IF/ID pipeline register
- `id_ex_reg.sv`: ID/EX pipeline register
- `ex_mem_reg.sv`: EX/MEM pipeline register
- `mem_wb_reg.sv`: MEM/WB pipeline register
- `forwarding_unit.sv`: EX-stage operand forwarding control
- `load_use_hazard_unit.sv`: one-cycle load-use hazard detector
- `pipeline_control.sv`: PC stall/redirect and pipeline flush arbiter
- `icache.sv`: direct-mapped instruction cache
- `dcache.sv`: set-associative, write-back data cache
- `slow_line_memory.sv`: variable-latency backing-memory model
- `mul_unit.sv`, `div_unit.sv`, `muldiv_unit.sv`: RV32M execution path

## Current Status

The pipeline modules and top-level RV32IM, cache-overlap, fault, and
differential scoreboard tests pass in Questa. The frozen timing result and the
interface rules are recorded in `docs/pipeline-baseline.md` and
`docs/pipeline-interfaces.md`.

## Ownership Reminder

Coordinate changes to module ports, package structs, bubble constants, and the
top-level wiring before editing shared interfaces. Small local implementation
changes are fine, but anything that changes a field name, width, enum, or
pipeline-register payload needs both teammates to know.
