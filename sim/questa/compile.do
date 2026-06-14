transcript on

if {![info exists work_lib]} {
    set work_lib work
}

if {[file exists $work_lib]} {
    vdel -lib $work_lib -all
}

vlib $work_lib

# Compile the shared package before every module that imports it.
vlog -work $work_lib -sv ../../rtl/common/rv32i_pkg.sv
vlog -work $work_lib -sv ../../rtl/common/pc.sv
vlog -work $work_lib -sv ../../rtl/common/imem.sv
vlog -work $work_lib -sv ../../rtl/common/imm_gen.sv
vlog -work $work_lib -sv ../../rtl/common/branch_unit.sv
vlog -work $work_lib -sv ../../rtl/common/decoder.sv
vlog -work $work_lib -sv ../../rtl/common/alu.sv
vlog -work $work_lib -sv ../../rtl/common/regfile.sv
vlog -work $work_lib -sv ../../rtl/common/dmem.sv

# Completed single-cycle reference core.
vlog -work $work_lib -sv ../../rtl/single_cycle/core_single_cycle.sv

vlog -work $work_lib -sv ../../tb/unit/common/pc_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/imem_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/imm_gen_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/branch_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/decoder_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/alu_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/regfile_tb.sv
vlog -work $work_lib -sv ../../tb/unit/common/dmem_tb.sv
vlog -work $work_lib -sv ../../tb/integration/single_cycle/core_single_cycle_tb.sv
