# Replace this part with the exact device for your FPGA board.
set part_name "xc7a35tcpg236-1"
set project_name "ooop_riscv"
set project_dir [file normalize "./build"]
set repo_root [file normalize "../.."]

create_project -force $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

read_verilog -sv [glob "$repo_root/rtl/*.sv"]
set_property top core_single_cycle [current_fileset]

# The core has no physical board I/O wrapper yet, so constraints are optional.
set xdc_file "$repo_root/synth/vivado/constraints.xdc"
if {[file exists $xdc_file]} {
  read_xdc $xdc_file
}

synth_design -top core_single_cycle -part $part_name
report_utilization -file "$project_dir/utilization.rpt"
report_timing_summary -file "$project_dir/timing_summary.rpt"
write_checkpoint -force "$project_dir/post_synth.dcp"

puts "Synthesis complete. Reports are in $project_dir"
