#!/bin/bash

CORE_UTILIZATION_VALUES=(59 64 65 66)
DESIGN_CONFIG="designs/rapidus2hp/hercules_is_int/config.mk"

# CORE_UTILIZATION_VALUES=(50 51 52 53 54 55 56 57)
# DESIGN_CONFIG="designs/rapidus2hp/gcd/config.mk"


#DESIGN_CONFIG="designs/sky130hs/ibex/config.mk"

STRING_PARAM="$1"
#SYNTH_HDL_FRONTEND=verific \

for CORE_UTILIZATION in "${CORE_UTILIZATION_VALUES[@]}"; do
    # Construct the command string clearly
    CMD="make \
    DESIGN_CONFIG='$DESIGN_CONFIG' \
    FLOW_VARIANT='$CORE_UTILIZATION' \
    CORE_UTILIZATION='$CORE_UTILIZATION' \
    PLATFORM_HOME=/platforms \
    $STRING_PARAM"

    echo "----------------------------------------"
    echo "Check: Launching terminal for density ${CORE_UTILIZATION}..."
    echo "Command: $CMD"
    echo "----------------------------------------"

    # Pass the variable to the terminal
    gnome-terminal -- bash -c "$CMD; exec bash"
    
    sleep 0.5
done

wait

echo "All jobs completed."
