do compile.do
vsim -c -voptargs=+acc work.core_single_cycle_tb
run -all
quit -sim
echo "Core integration test completed"
