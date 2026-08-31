source $::env(SCRIPTS_DIR)/load.tcl
erase_non_stage_variables place

# global_placement -place_ios does this itself, against the cell placement it
# ends on. A design it cannot run on still needs its pins placed here.
if { [place_ios_enabled] } {
  orfs_copy_db $::env(RESULTS_DIR)/3_1_place_gp_skip_io.odb \
    $::env(RESULTS_DIR)/3_2_place_iop.odb
} else {
  load_design 3_1_place_gp_skip_io.odb 2_floorplan.sdc
  source_step_tcl PRE IO_PLACEMENT
  log_cmd place_pins \
    -hor_layers $::env(IO_PLACER_H) \
    -ver_layers $::env(IO_PLACER_V) \
    {*}[env_var_or_empty PLACE_PINS_ARGS]
  report_design_area

  orfs_write_db $::env(RESULTS_DIR)/3_2_place_iop.odb
  write_pin_placement $::env(RESULTS_DIR)/3_2_place_iop.tcl
}

source_step_tcl POST IO_PLACEMENT
