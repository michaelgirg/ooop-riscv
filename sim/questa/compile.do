transcript on

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# Compile only completed RTL modules.
vlog -sv ../../rtl/pc.sv
vlog -sv ../../rtl/imem.sv
vlog -sv ../../rtl/imm_gen.sv
vlog -sv ../../rtl/branch_unit.sv
vlog -sv ../../rtl/decoder.sv

vlog -sv ../../tb/unit/pc_tb.sv
vlog -sv ../../tb/unit/imem_tb.sv
vlog -sv ../../tb/unit/imm_gen_tb.sv
vlog -sv ../../tb/unit/branch_unit_tb.sv
vlog -sv ../../tb/unit/decoder_tb.sv
