onerror {quit -code 1}

set work_lib pipeline_core_work
do compile_pipeline.do

# The differential scoreboard uses the passing single-cycle RV32IM core as its
# architectural reference while the cached pipeline runs independently.
vlog -work $work_lib -sv ../../rtl/single_cycle/muldiv_single_cycle.sv
vlog -work $work_lib -sv ../../rtl/single_cycle/core_single_cycle.sv

vlog -work $work_lib -sv ../../rtl/pipeline/core_pipeline.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/architecture_counters.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_tb.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_m_tb.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_cache_tb.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_cache_fault_tb.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_scoreboard_tb.sv

foreach test {core_pipeline_tb core_pipeline_m_tb core_pipeline_cache_tb core_pipeline_cache_fault_tb core_pipeline_scoreboard_tb} {
    echo "Running $test"
    # Preserve only the test's error counter. This lets the runner propagate a
    # failure without enabling full +acc visibility on the cache-heavy design.
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

echo "Pipeline core integration tests completed"
quit -code 0
