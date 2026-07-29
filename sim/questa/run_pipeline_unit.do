onerror {quit -code 1}

set work_lib pipeline_unit_work
do compile_pipeline.do

foreach test {if_id_reg_tb id_ex_reg_tb ex_mem_reg_tb mem_wb_reg_tb forwarding_unit_tb load_use_hazard_unit_tb pipeline_control_tb mul_unit_tb div_unit_tb muldiv_unit_tb slow_line_memory_tb plru_tb dcache_tb icache_tb} {
    echo "Running $test"
    # Preserve only the test's error counter. Questa 2021.2 can crash when
    # full +acc visibility is applied to the large I-cache testbench.
    vsim -c -voptargs="-access=r+/$test/errors" $work_lib.$test
    onfinish stop
    run -all

    set test_errors [examine -radix decimal /$test/errors]
    if {$test_errors != 0} {
        echo "FAILED: $test reported $test_errors errors"
        quit -sim
        quit -code 1
    }

    quit -sim
}

echo "All completed pipeline unit tests finished"
quit -code 0
