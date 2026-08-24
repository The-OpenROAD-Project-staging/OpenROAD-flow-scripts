source $::env(SCRIPTS_DIR)/load.tcl
erase_non_stage_variables place

# place_pins moved to the end of 3_3, where it legalizes the pin locations
# global_placement -place_ios picked.
orfs_copy_db $::env(RESULTS_DIR)/3_1_place_gp_skip_io.odb $::env(RESULTS_DIR)/3_2_place_iop.odb

source_step_tcl POST IO_PLACEMENT
