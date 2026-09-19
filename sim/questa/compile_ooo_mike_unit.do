transcript on

if {![info exists work_lib]} {
    set work_lib ooo_mike_unit_work
}

# Recreate the generated library so stale compiled units cannot hide an
# interface change.
if {[file isdirectory $work_lib]} {
    catch {vdel -lib $work_lib -all}
}

vlib $work_lib

# Package order matters: the OOO package reuses RV32IM decode/control types.
vlog -work $work_lib -sv ../../rtl/common/rv32i_pkg.sv
vlog -work $work_lib -sv ../../rtl/ooo/ooo_pkg.sv

# Mike-owned OOO RTL.
foreach source {
    physical_regfile.sv
    rename_map.sv
    free_list.sv
    rob.sv
    commit_unit.sv
} {
    vlog -work $work_lib -sv ../../rtl/ooo/$source
}

# Self-checking procedural tests. These do not require an SVA license.
foreach test {
    physical_regfile_tb.sv
    rename_map_tb.sv
    free_list_tb.sv
    rob_tb.sv
    commit_unit_tb.sv
} {
    vlog -work $work_lib -sv ../../tb/unit/ooo/$test
}
