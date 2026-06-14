onerror {quit -code 1}

set work_lib core_work
do compile.do
vsim -c -voptargs=+acc $work_lib.core_single_cycle_tb
run -all
quit -sim
echo "Core integration test completed"
quit -code 0
