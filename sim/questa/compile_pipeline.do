transcript on

if {![info exists work_lib]} {
    set work_lib pipeline_work
}

if {[file exists $work_lib]} {
    vdel -lib $work_lib -all
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

# Pipeline files are currently comment-only placeholders. Add each file to
# this list as soon as it contains a complete module.
#
# vlog -work $work_lib -sv ../../rtl/pipeline/if_id_reg.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/id_ex_reg.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/ex_mem_reg.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/mem_wb_reg.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/forwarding_unit.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/load_use_hazard_unit.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/pipeline_control.sv
# vlog -work $work_lib -sv ../../rtl/pipeline/core_pipeline.sv
# vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_tb.sv
