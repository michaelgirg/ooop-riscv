transcript on
onerror {quit -code 1}

if {![info exists work_lib]} {
    set work_lib ooo_work
}

# Always rebuild so an old compiled interface cannot hide an RTL change.
if {[file isdirectory $work_lib]} {
    catch {vdel -lib $work_lib -all}
}
vlib $work_lib

# Packages must be compiled before every module that imports their types.
vlog -work $work_lib -sv ../../rtl/common/rv32i_pkg.sv
vlog -work $work_lib -sv ../../rtl/ooo/ooo_pkg.sv

foreach source {
    decoder.sv
    imm_gen.sv
    alu.sv
    branch_unit.sv
} {
    vlog -work $work_lib -sv ../../rtl/common/$source
}

# Reuse the already verified RV32M implementation from the in-order pipeline.
foreach source {
    mul_unit.sv
    div_unit.sv
    muldiv_unit.sv
} {
    vlog -work $work_lib -sv ../../rtl/pipeline/$source
}

foreach source {
    physical_regfile.sv
    rename_map.sv
    free_list.sv
    rob.sv
    commit_unit.sv
    ooo_frontend.sv
    rename_stage.sv
    issue_queue.sv
    execute_cluster.sv
    memory_queue.sv
    result_arbiter.sv
    ooo_control.sv
    core_ooo.sv
} {
    vlog -work $work_lib -sv ../../rtl/ooo/$source
}

foreach test {
    physical_regfile_tb.sv
    rename_map_tb.sv
    free_list_tb.sv
    rob_tb.sv
    commit_unit_tb.sv
    ooo_frontend_tb.sv
    rename_stage_tb.sv
    issue_queue_tb.sv
    execute_cluster_tb.sv
    memory_queue_tb.sv
    result_arbiter_tb.sv
    ooo_control_tb.sv
} {
    vlog -work $work_lib -sv ../../tb/unit/ooo/$test
}

vlog -work $work_lib -sv ../../tb/integration/ooo/core_ooo_tb.sv
