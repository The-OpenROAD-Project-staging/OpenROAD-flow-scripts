utl::set_metrics_stage "globalplace__{}"
source $::env(SCRIPTS_DIR)/load.tcl
erase_non_stage_variables place
load_design 3_2_place_iop.odb 2_floorplan.sdc
source_step_tcl PRE GLOBAL_PLACE

set_dont_use $::env(DONT_USE_CELLS)

if { $::env(GPL_TIMING_DRIVEN) } {
  remove_buffers
}

# Do not buffer chip-level designs
# by default, IO ports will be buffered
# to not buffer IO ports, set environment variable
# DONT_BUFFER_PORT = 1
if { ![env_var_exists_and_non_empty FOOTPRINT] } {
  if { !$::env(DONT_BUFFER_PORTS) } {
    puts "Perform port buffering..."
    buffer_ports {*}[env_var_or_empty BUFFER_PORTS_ARGS]
  }
}

set global_placement_args {}

# Parameters for routability mode in global placement
append_env_var global_placement_args GPL_ROUTABILITY_DRIVEN -routability_driven 0

append_env_var global_placement_args GPL_RANDOM_SEED -random_seed 1

# Parameters for timing driven mode in global placement
if { $::env(GPL_TIMING_DRIVEN) } {
  lappend global_placement_args {-timing_driven}
  if { [info exists ::env(GPL_KEEP_OVERFLOW)] } {
    lappend global_placement_args -keep_resize_below_overflow $::env(GPL_KEEP_OVERFLOW)
  }
}

# Parameters for phi coefficients in global placement
set min_phi $::env(MIN_PLACE_STEP_COEF)
set max_phi $::env(MAX_PLACE_STEP_COEF)

if { $min_phi > $max_phi } {
  utl::error GPL 200 \
    "MIN_PLACE_STEP_COEF ($min_phi) cannot be greater than \
MAX_PLACE_STEP_COEF ($max_phi)"
}

lappend global_placement_args -force_center_initial_place

lappend global_placement_args -min_phi_coef $::env(MIN_PLACE_STEP_COEF)
lappend global_placement_args -max_phi_coef $::env(MAX_PLACE_STEP_COEF)

# The only global placement the flow runs: -place_ios co-optimizes the movable
# IO pins with the cells and hands them to the pin placer itself, so there is no
# place_pins call after it.
set place_ios [place_ios_enabled]
if { $place_ios } {
  lappend global_placement_args -place_ios
  # The solve places the pins on these layers and builds its slot grid from
  # their tracks, so they have to be the ones the flow would route them on.
  lappend global_placement_args -place_ios_hor_layers $::env(IO_PLACER_H)
  lappend global_placement_args -place_ios_ver_layers $::env(IO_PLACER_V)
  # Spacing and the periodic ppl assignment are on by default; 50 iterations is
  # that default, stated here so the other flows can vary it against this one.
  lappend global_placement_args -place_ios_legalize_every 50
  # Whatever the flow would have run place_pins with, the solve has to run its
  # own assignment with: a design that packs its pins tighter than the default
  # two tracks otherwise models a coarser grid than it will be placed on.
  set place_pins_args [env_var_or_empty PLACE_PINS_ARGS]
  if {
    [lsearch -exact $place_pins_args -min_distance_in_tracks] >= 0
    && [set i [lsearch -exact $place_pins_args -min_distance]] >= 0
  } {
    lappend global_placement_args -place_ios_min_distance_tracks \
      [lindex $place_pins_args [expr { $i + 1 }]]
  }
  if { [lsearch -exact $place_pins_args -annealing] >= 0 } {
    lappend global_placement_args -place_ios_annealing
  }
  # rsz and STA read the pin locations during a timing-driven iteration.
  if { $::env(GPL_TIMING_DRIVEN) } {
    lappend global_placement_args -place_ios_td_preview
  }
}

proc do_placement { global_placement_args } {
  set all_args [concat [list -density [place_density_with_lb_addon] \
    -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT)] \
    $global_placement_args]

  lappend all_args {*}[env_var_or_empty GLOBAL_PLACEMENT_ARGS]

  log_cmd global_placement {*}$all_args
}

set result [catch { do_placement $global_placement_args } errMsg]
if { $result != 0 } {
  orfs_write_db $::env(RESULTS_DIR)/3_3_place_gp-failed.odb
  error $errMsg
}

if { $place_ios } {
  write_pin_placement $::env(RESULTS_DIR)/3_3_place_gp_pins.tcl
}

log_cmd estimate_parasitics -placement

if { $::env(CLUSTER_FLOPS) } {
  log_cmd cluster_flops {*}[env_var_or_empty CLUSTER_FLOPS_ARGS]
  log_cmd estimate_parasitics -placement
}

report_metrics 3 "global place" false false

source_step_tcl POST GLOBAL_PLACE

orfs_write_db $::env(RESULTS_DIR)/3_3_place_gp.odb
