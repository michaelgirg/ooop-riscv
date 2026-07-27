# Batch synthesis target for the cached five-stage pipeline.

# ZedBoard: AMD Zynq-7000 XC7Z020 in the CLG484 package, speed grade -1.
# Targeting the device directly does not require the optional Avnet board files.
set part_name "xc7z020clg484-1"
set project_name "ooop_riscv_pipeline"

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize "$script_dir/build_pipeline"]
set repo_root [file normalize "$script_dir/../.."]
set synth_hex [file normalize "$repo_root/tb/programs/synth_test_lines.hex"]

create_project -force $project_name $project_dir -part $part_name
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Packages must be parsed before modules that import their types.
read_verilog -sv [list "$repo_root/rtl/common/rv32i_pkg.sv"]
set rtl_sources [concat \
  [glob "$repo_root/rtl/common/*.sv"] \
  [glob "$repo_root/rtl/pipeline/*.sv"]]
set package_index [lsearch -exact $rtl_sources "$repo_root/rtl/common/rv32i_pkg.sv"]
if {$package_index >= 0} {
  set rtl_sources [lreplace $rtl_sources $package_index $package_index]
}
read_verilog -sv [list {*}$rtl_sources]

if {![file exists $synth_hex]} {
  error "Synthesis program image not found: $synth_hex"
}

set_property top core_pipeline [current_fileset]
set_property generic [list \
  "IMEM_HEX=$synth_hex" \
  "IMEM_LATENCY=15" \
  "DMEM_LATENCY=15"] [current_fileset]

set xdc_file "$repo_root/synth/vivado/constraints.xdc"
if {[file exists $xdc_file]} {
  read_xdc [list $xdc_file]
}

synth_design -top core_pipeline -part $part_name -flatten_hierarchy rebuilt

# Save the synthesized design before generating reports. If report generation
# is interrupted, run_pipeline_synth.ps1 -ReportsOnly can reopen this checkpoint
# instead of repeating synthesis.
write_checkpoint -force "$project_dir/post_synth.dcp"

# Post-synthesis timing uses estimated, unplaced routes. Implement the design
# before reporting timing so the result reflects actual ZedBoard placement and
# routing congestion.
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force "$project_dir/post_route.dcp"

report_utilization -hierarchical -file "$project_dir/utilization.rpt"
report_timing_summary -delay_type max -max_paths 20 \
  -file "$project_dir/timing_summary.rpt"
report_methodology -file "$project_dir/methodology.rpt"
report_route_status -file "$project_dir/route_status.rpt"

set worst_path [get_timing_paths -delay_type max -max_paths 1]
if {[llength $worst_path] > 0} {
  puts "Pipeline post-synthesis worst slack: [get_property SLACK $worst_path] ns"
}

puts "Pipeline implementation complete. Reports are in $project_dir"
