#!/bin/bash

LOG_FILE="${HOME}/demo/logs/startup.log"
LLM_LOG_FILE="${HOME}/demo/logs/LLM_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$LLM_LOG_FILE")"

echo "==== Starting LLM containers on 1P Server ====" >> "$LOG_FILE"
echo "Script started at: $(date)" >> "$LOG_FILE"
echo "Logs will be stored in $LOG_FILE" >> "$LOG_FILE"

ssh -q -o "LogLevel=ERROR" -t 1p << 'EOF' >> "$LLM_LOG_FILE" 2>&1 &
  
  # CPU pinning sets
  CCD_CORES_PINNING_LIST1=("0,1,2,3,4,5,8,9,10,11,12,16,17,18,19,20,21,24,25,26,27,28,32,33,34,35,36,40,41,42,43,44,45,48,49,50,51,52,56,57,58,59,60,64,65,66,67,68,70,72,73,74,75,76,80,81,82,83,84,88,89,90,91,92")

  echo "Sourcing parameters file..."

  # Source the parameters file
  source "./demo/scripts/parameters.sh"

  # Deepseek1.5b
  echo "Starting Deepseek1.5b Model..."
  docker run -d --rm --name "1P_DS-1.5b" --cpuset-cpus "${CCD_CORES_PINNING_LIST1}" \
      --memory "48GiB" --env "HUGGING_FACE_HUB_TOKEN=${LLM_HF_TOKEN}" \
      -v "${LLM_DS_MODEL_LOCATION}:/deepseek1.5b" -p "${LLM_DS_HOST_PORT}:8000" \
      "${LLM_DEPLOY_DI}" \
      --model /deepseek1.5b

  echo "Sleeping for 10 seconds..."
  sleep 10

  # Check if Deepseek1.5b container is running
  echo "Checking if the Deepseek1.5b container is running..."
  if docker ps --format '{{.Names}}' | grep -q '^1P_DS-1.5b$'; then
      echo "✅ Deepseek1.5b container is running successfully."
  else
      echo "❌ ERROR: Deepseek1.5b container failed to start!"
      exit 1
  fi

  echo "All LLM services started successfully at: $(date)"

EOF

sleep 10
echo "==== Script execution completed on 1P Server ====" >> "$LOG_FILE"