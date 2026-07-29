# Regenerate cached-pipeline reports from an existing post-synthesis checkpoint.

set script_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize "$script_dir/build_pipeline"]
set synth_checkpoint [file normalize "$project_dir/post_synth.dcp"]
set route_checkpoint [file normalize "$project_dir/post_route.dcp"]

if {[file exists $route_checkpoint]} {
  open_checkpoint $route_checkpoint
} elseif {[file exists $synth_checkpoint]} {
  open_checkpoint $synth_checkpoint

  # Complete implementation from the saved synthesis result. This path avoids
  # repeating synthesis when report generation or implementation is stopped.
  opt_design
  place_design
  phys_opt_design -directive AggressiveExplore
  route_design -directive Explore
  write_checkpoint -force $route_checkpoint
} else {
  error "Pipeline checkpoint not found in $project_dir"
}

report_utilization -hierarchical -file "$project_dir/utilization.rpt"
report_timing_summary -delay_type max -max_paths 20 \
  -file "$project_dir/timing_summary.rpt"
report_methodology -file "$project_dir/methodology.rpt"
report_route_status -file "$project_dir/route_status.rpt"

set worst_path [get_timing_paths -delay_type max -max_paths 1]
if {[llength $worst_path] > 0} {
  puts "Pipeline post-synthesis worst slack: [get_property SLACK $worst_path] ns"
}

puts "Pipeline post-route reports are in $project_dir"
