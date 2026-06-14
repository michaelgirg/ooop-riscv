# Pipeline RTL

This directory contains the five-stage pipelined core. The files are
intentionally comment-only placeholders so the team can implement the RTL.

- `core_pipeline.sv`: shared top-level integration
- `forwarding_unit.sv`: Person A
- `load_use_hazard_unit.sv`: Person A
- `id_ex_reg.sv`: Person A
- `ex_mem_reg.sv`: Person A
- `pipeline_control.sv`: Person B
- `if_id_reg.sv`: Person B
- `mem_wb_reg.sv`: Person B

Coordinate changes to module ports and pipeline-register contents before
editing the shared top level.
