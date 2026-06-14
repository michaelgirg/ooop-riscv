transcript on

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# Compile the package before every module that imports it.
vlog -sv ../../rtl/rv32i_pkg.sv
vlog -sv ../../rtl/pc.sv
vlog -sv ../../rtl/imem.sv
vlog -sv ../../rtl/imm_gen.sv
vlog -sv ../../rtl/branch_unit.sv
vlog -sv ../../rtl/decoder.sv
vlog -sv ../../rtl/alu.sv
vlog -sv ../../rtl/regfile.sv
vlog -sv ../../rtl/dmem.sv

vlog -sv ../../tb/unit/pc_tb.sv
vlog -sv ../../tb/unit/imem_tb.sv
vlog -sv ../../tb/unit/imm_gen_tb.sv
vlog -sv ../../tb/unit/branch_unit_tb.sv
vlog -sv ../../tb/unit/decoder_tb.sv
vlog -sv ../../tb/unit/alu_tb.sv
vlog -sv ../../tb/unit/regfile_tb.sv
vlog -sv ../../tb/unit/dmem_tb.sv
