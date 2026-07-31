onerror {quit -code 1}

set work_lib ooo_mike_unit_work
do compile_ooo_mike_unit.do

foreach test {
    physical_regfile_tb
    rename_map_tb
    free_list_tb
    rob_tb
    commit_unit_tb
} {
    echo "Running $test"
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

echo "All Mike OOO unit tests passed"
quit -code 0
