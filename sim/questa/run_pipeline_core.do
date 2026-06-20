onerror {quit -code 1}

set work_lib pipeline_core_work
do compile_pipeline.do

vlog -work $work_lib -sv ../../rtl/pipeline/core_pipeline.sv
vlog -work $work_lib -sv ../../tb/integration/pipeline/core_pipeline_tb.sv

vsim -c -voptargs=+acc $work_lib.core_pipeline_tb
run -all
quit -sim

echo "Pipeline core integration test completed"
quit -code 0
