onerror {quit -code 1}

set work_lib pipeline_unit_work
do compile_pipeline.do

foreach test {if_id_reg_tb id_ex_reg_tb ex_mem_reg_tb mem_wb_reg_tb forwarding_unit_tb load_use_hazard_unit_tb pipeline_control_tb mul_unit_tb div_unit_tb muldiv_unit_tb plru_tb dcache_tb} {
    echo "Running $test"
    vsim -c -voptargs=+acc $work_lib.$test
    onfinish stop
    run -all
    quit -sim
}

# Re-run the same D-cache model against wider set-associative configurations.
# The standalone PLRU test checks exact victim choices; these runs check that
# wider cache arrays preserve request/response and architectural memory behavior.
foreach ways {4 8} {
    echo "Running dcache_tb with NUM_WAYS=$ways"
    vsim -c -voptargs=+acc -gNUM_WAYS=$ways $work_lib.dcache_tb
    onfinish stop
    run -all
    quit -sim
}

echo "All completed pipeline unit tests finished"
quit -code 0
