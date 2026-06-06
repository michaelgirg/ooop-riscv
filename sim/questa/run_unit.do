do compile.do

foreach test {alu_tb regfile_tb imm_gen_tb decoder_tb} {
  echo "Running $test"
  vsim -c -voptargs=+acc work.$test
  run -all
  quit -sim
}

echo "All unit tests completed"
