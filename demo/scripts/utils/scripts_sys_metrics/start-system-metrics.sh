#!/bin/bash

source "${HOME}/demo/scripts/parameters.sh"

LOG_FILE="${HOME}/demo/logs/SYS_METRICS_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# List of remote hosts
hosts=("1p" "2p" "2pc_a" "2pc_b")

# List of arguments to pass to the python script (one per host)
args=("1P_SYSTEM" "2P_SYSTEM" "2PC_SYSTEM_A" "2PC_SYSTEM_B")

# Local folder containing your Python script and requirements.txt
local_folder="${HOME}/demo/scripts/utils/scripts_sys_metrics/sys_metrics"

# Name of the Python script inside the folder (expects one argument)
python_script="system_metrics.py"

# Remote destination folder
remote_folder="${HOME}/demo/scripts/utils/scripts_sys_metrics/sys_metrics"

# Remote path for the virtual environment
remote_venv="$remote_folder/venv"

# Redirect all output (stdout & stderr) to the log file
exec > >(tee -a "$LOG_FILE" > /dev/null) 2>&1

# Loop through each host and corresponding argument
for i in "${!hosts[@]}"; do
    host="${hosts[$i]}"
    arg="${args[$i]}"

    echo "Deploying to $host with argument: $arg"

    # Remove existing directory on the remote machine
    ssh "$host" "rm -rf $remote_folder"

    # Sync the local folder to the remote machine using rsync
    rsync -av --delete "$local_folder/" "$host:$remote_folder/"

    if [ $? -eq 0 ]; then
        echo "Successfully synchronized $local_folder to $host:$remote_folder"

        # Connect to the remote host and execute the script setup
        ssh "$host" "bash -c '
            cd $remote_folder &&

            # Create a virtual environment (if not exists)
            python3 -m venv venv &&

            # Activate the virtual environment
            source venv/bin/activate &&

            # Install requirements if requirements.txt exists
            if [ -f requirements.txt ]; then
                pip install --upgrade pip && pip install -r requirements.txt;
            fi

            # Run the Python script in the background
            nohup python3 $python_script -q $arg -n $RABBITMQ_HOST -u $RABBITMQ_USER -p $RABBITMQ_PASSWORD > sys_metrics.log 2>&1 &
            exit
        '" &

        echo "Script started on $host."
    else
        echo "Error: Failed to copy $local_folder to $host."
    fi
done
