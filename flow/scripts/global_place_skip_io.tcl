source $::env(SCRIPTS_DIR)/load.tcl
erase_non_stage_variables place
load_design 2_floorplan.odb 2_floorplan.sdc
source_step_tcl PRE GLOBAL_PLACE_SKIP_IO

# 3_3 runs a single global_placement -place_ios that co-optimizes the cells and
# the IO pins, so there is no IO-blind placement to run first.
puts "Concurrent IO placement is enabled. Skipping global placement without IOs"

source_step_tcl POST GLOBAL_PLACE_SKIP_IO

report_design_area

orfs_write_db $::env(RESULTS_DIR)/3_1_place_gp_skip_io.odb
