#!/bin/bash

LOG_FILE="${HOME}/demo/logs/LLM_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect all output (stdout & stderr) to the log file
exec > >(tee -a "$LOG_FILE" > /dev/null) 2>&1

source "${HOME}/demo/scripts/parameters.sh"

cd "${HOME}/demo/config" || exit 1
CONFIG_FILE="1P_DS_config.json"

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
    "inference_server": "vllm",
    "model": "",
    "random_prompt": true,
    "max_requests": 1,
    "user_counts": [10]
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
    config["topic"] = "$LLM_1P_TOPIC"
    config["mqtt_user"] = "$RABBITMQ_USER"
    config["mqtt_pass"] = "$RABBITMQ_PASSWORD"
    config["mqtt_ip"] = "$RABBITMQ_HOST"
    config["base_url"] = "$ENDPOINT_1P_LLM_DS"
    config["model"] = "/deepseek1.5b"

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

for i in {1..10}
do
  echo "Run #$i"  
  echo "------------------ Response from Deepseek ---------------------"
  curl -s -X POST "${ENDPOINT_1P_LLM_DS}" \
       -H "Content-Type: application/json" \
       -d '{
             "prompt": "What is machine learning?",
             "model": "/deepseek1.5b",
             "max_tokens": 32,
             "stream": true
           }'

  echo -e "\n------------------------\n"
done

docker run -d --rm --name "1P_loadgen_DS" -e CONFIG_PATH=/app/EchoSwift/config.json \
           -v ./1P_DS_config.json:/app/EchoSwift/config.json \
           "${LLM_LOADGEN_DI}" >> "$LOG_FILE" 2>&1 &
