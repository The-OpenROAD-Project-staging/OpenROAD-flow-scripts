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
# IO pins with the cells, and place_pins below legalizes what it picks. Unusable
# on a design whose pins the floorplan already placed.
set place_ios 1
if {
  [env_var_exists_and_non_empty FLOORPLAN_DEF]
  || [env_var_exists_and_non_empty FOOTPRINT]
  || [env_var_exists_and_non_empty FOOTPRINT_TCL]
  || [all_pins_placed]
} {
  set place_ios 0
}
if { $place_ios } {
  lappend global_placement_args -place_ios
  # The solve writes the pin shapes itself, and the mid-solve legalization
  # builds ppl's slot grid, so both need the layers place_pins uses below.
  lappend global_placement_args -place_ios_hor_layers $::env(IO_PLACER_H)
  lappend global_placement_args -place_ios_ver_layers $::env(IO_PLACER_V)
  # The pins are the only objects in the solve with no density force, so the
  # wirelength gradient stacks them past what place_pins below can honour. The
  # rank term is what carries it down the edge: a pin aims at the slot its
  # order entitles it to, so crowding ahead of it displaces it too.
  lappend global_placement_args -place_ios_density
  lappend global_placement_args -place_ios_density_rank
  # The force alone never finishes: hand the pins to ppl periodically and adopt
  # the assignment, so the cells only ever settle against positions place_pins
  # can reproduce.
  lappend global_placement_args -place_ios_legalize_every 50
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

# Concurrent IO placement writes the solved pin locations to the database but
# does not legalize them onto routing-track slots, the same way global placement
# leaves the cells for detailed placement. Run place_pins once against the final
# cell positions to assign the slots. Skipping it costs routed wirelength: on a
# 186k-instance design, setup WNS -0.060 -> -0.139 ns and global-route
# wirelength +5.1%.
if { $place_ios } {
  log_cmd place_pins \
    -hor_layers $::env(IO_PLACER_H) \
    -ver_layers $::env(IO_PLACER_V) \
    {*}[env_var_or_empty PLACE_PINS_ARGS]
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
