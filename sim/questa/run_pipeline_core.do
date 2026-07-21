onerror {quit -code 1}

set work_lib pipeline_core_work
do compile_pipeline.do

vlog -work $work_lib -sv ../../rtl/pipeline/core_pipeline.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_tb.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_m_tb.sv

foreach test {core_pipeline_tb core_pipeline_m_tb} {
    echo "Running $test"
    vsim -c -voptargs=+acc $work_lib.$test
    onfinish stop
    run -all
    quit -sim
}

echo "Pipeline core integration tests completed"
quit -code 0
