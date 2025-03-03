#!/bin/bash

# List of remote hosts
hosts=("1p" "2p" "2pc_a" "2pc_b")

# Pattern to match the deployed Python script process
process_pattern="system_metrics.py"

for host in "${hosts[@]}"; do
    echo "Attempting to kill process matching '$process_pattern' on $host"

    ssh "$host" "bash -c '
        if pgrep -f \"$process_pattern\" > /dev/null; then
            pkill -f \"$process_pattern\"
            if [ \$? -eq 0 ]; then
                echo \"Process terminated on $host.\"
            else
                echo \"Failed to kill process on $host.\"
            fi
        else
            echo \"No matching process found on $host.\"
        fi
    '" &
done

wait  # Ensures all SSH sessions complete before script exits
