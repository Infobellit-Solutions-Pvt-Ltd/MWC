#!/bin/bash

source ${HOME}/demo/scripts/parameters.sh

LOG_FILE="${HOME}/demo/logs/POW_METRICS_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect all output (stdout & stderr) to the log file
exec > >(tee -a "$LOG_FILE" > /dev/null) 2>&1

# Define container and image name
IMAGE_NAME="power_metrics"
CONTAINER_NAME="power_metrics_container"
CONFIG_FILE="power_metrics/bangalore.txt"  # Modify as needed

# Build the Docker image
echo "Building Docker image..."
docker build -t $IMAGE_NAME ${HOME}/demo/scripts/utils/power_metrics/

# Run the container, passing the RabbitMQ host as an environment variable
echo "Running Docker container with config file: $CONFIG_FILE"
docker run -d -p 5000:5000 --name $CONTAINER_NAME -e RABBITMQ_HOST=$RABBITMQ_HOST $IMAGE_NAME $CONFIG_FILE

echo "Container is running. Access Flask API at http://localhost:5000"

