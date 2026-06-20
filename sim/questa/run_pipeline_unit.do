onerror {quit -code 1}

set work_lib pipeline_unit_work
do compile_pipeline.do

foreach test {if_id_reg_tb id_ex_reg_tb ex_mem_reg_tb mem_wb_reg_tb forwarding_unit_tb load_use_hazard_unit_tb pipeline_control_tb} {
    echo "Running $test"
    vsim -c -voptargs=+acc $work_lib.$test
    run -all
    quit -sim
}

echo "All completed pipeline unit tests finished"
quit -code 0
