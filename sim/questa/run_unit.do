do compile.do

foreach test {pc_tb imem_tb imm_gen_tb branch_unit_tb decoder_tb} {
    echo "Running $test"
    vsim -c -voptargs=+acc work.$test
    run -all
    quit -sim
}

echo "All completed-module unit tests finished"
