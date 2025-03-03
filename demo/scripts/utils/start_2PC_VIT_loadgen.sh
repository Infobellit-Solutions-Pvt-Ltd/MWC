#!/bin/bash

LOG_FILE="${HOME}/demo/logs/VIT_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect all output (stdout & stderr) to the log file
exec > >(tee -a "$LOG_FILE" > /dev/null) 2>&1

source "${HOME}/demo/scripts/parameters.sh"

cd ${HOME}/demo/config || exit
CONFIG_FILE=2PC_VIT_config.json

# If config file doesn't exist, create a default one
if [ ! -f "$CONFIG_FILE" ]; then
    cat <<EOF > "$CONFIG_FILE"
{
    "_comment": "EchoSwift Configuration",
    "out_dir": "test_results/",
    "topic": "",
    "mqtt_user": "",
    "mqtt_pass": "",
    "mqtt_ip": "",
    "base_url": "",
    "inference_server": "TorchServe",
    "max_requests": 1,
    "user_counts": [1],
}
EOF
fi

echo "############ Updating config file ###########"

python3 <<EOF
import json

config_file = "$CONFIG_FILE"

try:
    # Load JSON
    with open(config_file, "r") as f:
        config = json.load(f)

    # Update values from environment variables
    config["topic"] = "$VIT_2PC_TOPIC"
    config["mqtt_user"] = "$RABBITMQ_USER"
    config["mqtt_pass"] = "$RABBITMQ_PASSWORD"
    config["mqtt_ip"] = "$RABBITMQ_HOST"
    config["base_url"] = "$ENDPOINT_2PC_VIT"
    config["max_requests"] = $VIT_2PC_SAMPLE_SIZE
    config["user_counts"] = [$DOCKER_COMP_NUM_CONTAINERS_2PC_VIT]

    # Save JSON
    with open(config_file, "w") as f:
        json.dump(config, f, indent=4)

    print("✅ Updated", config_file, "successfully!")

except Exception as e:
    print(f"❌ Error updating {config_file}: {e}", file=sys.stderr)
    sys.exit(1)
EOF

if [ $? -eq 0 ]; then
    echo "Updated $CONFIG_FILE successfully!"
else
    echo "Error: Failed to update config file."
    exit 1
fi

docker run -d --rm --name "2PC_loadgen_vit" -e CONFIG_PATH=/app/EchoSwift/config.json \
           -v ./2PC_VIT_config.json:/app/EchoSwift/config.json \
           "${VIT_LOADGEN_DI}" >> "$LOG_FILE" 2>&1 &  
