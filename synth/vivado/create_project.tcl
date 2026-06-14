# Replace this part with the exact device for your FPGA board.
set part_name "xc7a35tcpg236-1"
set project_name "ooop_riscv"
set project_dir [file normalize "./build"]
set repo_root [file normalize "../.."]

create_project -force $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Packages must be parsed before modules that import them.
read_verilog -sv "$repo_root/rtl/common/rv32i_pkg.sv"
set rtl_sources [concat \
  [glob "$repo_root/rtl/common/*.sv"] \
  [glob "$repo_root/rtl/single_cycle/*.sv"]]
set package_index [lsearch -exact $rtl_sources "$repo_root/rtl/common/rv32i_pkg.sv"]
if {$package_index >= 0} {
  set rtl_sources [lreplace $rtl_sources $package_index $package_index]
}
read_verilog -sv $rtl_sources
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
