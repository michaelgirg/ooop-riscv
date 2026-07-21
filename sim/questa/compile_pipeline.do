transcript on

if {![info exists work_lib]} {
    set work_lib pipeline_work
}

# Start from a fresh Questa library. Generated libraries are not tracked,
# so this must also work from a clean checkout.
if {[file isdirectory $work_lib]} {
    catch {vdel -lib $work_lib -all}
}

vlib $work_lib

# Shared RTL. The package must be compiled first.
vlog -work $work_lib -sv ../../rtl/common/rv32i_pkg.sv
foreach source {
    pc.sv
    imem.sv
    imm_gen.sv
    branch_unit.sv
    decoder.sv
    alu.sv
    regfile.sv
    dmem.sv
} {
    vlog -work $work_lib -sv ../../rtl/common/$source
}

# Completed pipeline modules.
vlog -work $work_lib -sv ../../rtl/pipeline/if_id_reg.sv
vlog -work $work_lib -sv ../../rtl/pipeline/id_ex_reg.sv
vlog -work $work_lib -sv ../../rtl/pipeline/ex_mem_reg.sv
vlog -work $work_lib -sv ../../rtl/pipeline/mem_wb_reg.sv
vlog -work $work_lib -sv ../../rtl/pipeline/forwarding_unit.sv
vlog -work $work_lib -sv ../../rtl/pipeline/load_use_hazard_unit.sv
vlog -work $work_lib -sv ../../rtl/pipeline/pipeline_control.sv
vlog -work $work_lib -sv ../../rtl/pipeline/mul_unit.sv
vlog -work $work_lib -sv ../../rtl/pipeline/div_unit.sv
vlog -work $work_lib -sv ../../rtl/pipeline/muldiv_unit.sv
vlog -work $work_lib -sv ../../rtl/pipeline/plru.sv
vlog -work $work_lib -sv ../../rtl/pipeline/dcache.sv

# Pipeline unit tests for completed modules.
vlog -work $work_lib -sv ../../tb/unit/pipeline/if_id_reg_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/id_ex_reg_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/ex_mem_reg_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/mem_wb_reg_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/forwarding_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/load_use_hazard_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/pipeline_control_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/mul_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/div_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/muldiv_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/plru_tb.sv
vlog -work $work_lib -sv ../../tb/unit/pipeline/dcache_tb.sv

# Pipeline top-level integration is compiled by run_pipeline_core.do.
# vlog -work $work_lib -sv ../../rtl/pipeline/core_pipeline.sv
# vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_tb.sv
