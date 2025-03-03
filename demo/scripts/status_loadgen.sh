#!/bin/bash

# List of container names
CONTAINERS=(
    "1P_loadgen_DS"
    "1P_loadgen_vit"
    "2P_loadgen_DS"
    "2P_loadgen_vit"
    "2PC_loadgen_DS"
    "2PC_loadgen_vit"
    "power_metrics_container"
    # Add more container names here as needed
)

# Function to check if containers are running
check_containers() {
    local FAILED=0
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
            echo "✅ $container container is running."
        else
            echo "❌ ERROR: $container container failed to start!"
            FAILED=$((FAILED+1))
        fi
    done

    # Final status check
    if [[ $FAILED -gt 0 ]]; then
        echo ""
        echo "❌ $FAILED LOADGEN CONTAINERS FAILED TO START!"
        exit 1
    else
        echo "✅ All loadgen containers are running."
    fi
}

# Call the function
check_containers
