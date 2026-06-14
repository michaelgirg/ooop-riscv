transcript on

if {![info exists work_lib]} {
    set work_lib work
}

if {[file exists $work_lib]} {
    vdel -lib $work_lib -all
}

vlib $work_lib

# Compile the package before every module that imports it.
vlog -work $work_lib -sv ../../rtl/rv32i_pkg.sv
vlog -work $work_lib -sv ../../rtl/pc.sv
vlog -work $work_lib -sv ../../rtl/imem.sv
vlog -work $work_lib -sv ../../rtl/imm_gen.sv
vlog -work $work_lib -sv ../../rtl/branch_unit.sv
vlog -work $work_lib -sv ../../rtl/decoder.sv
vlog -work $work_lib -sv ../../rtl/alu.sv
vlog -work $work_lib -sv ../../rtl/regfile.sv
vlog -work $work_lib -sv ../../rtl/dmem.sv
vlog -work $work_lib -sv ../../rtl/core_single_cycle.sv

vlog -work $work_lib -sv ../../tb/unit/pc_tb.sv
vlog -work $work_lib -sv ../../tb/unit/imem_tb.sv
vlog -work $work_lib -sv ../../tb/unit/imm_gen_tb.sv
vlog -work $work_lib -sv ../../tb/unit/branch_unit_tb.sv
vlog -work $work_lib -sv ../../tb/unit/decoder_tb.sv
vlog -work $work_lib -sv ../../tb/unit/alu_tb.sv
vlog -work $work_lib -sv ../../tb/unit/regfile_tb.sv
vlog -work $work_lib -sv ../../tb/unit/dmem_tb.sv
vlog -work $work_lib -sv ../../tb/integration/core_single_cycle_tb.sv
