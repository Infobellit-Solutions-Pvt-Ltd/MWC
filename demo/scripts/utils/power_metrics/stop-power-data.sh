#!/bin/bash

# Define container name
CONTAINER_NAME="power_metrics_container"

# Stop the container if running
echo "Stopping container..."
docker stop $CONTAINER_NAME

# Remove the container
echo "Removing container..."
docker rm $CONTAINER_NAME

echo "Container stopped and removed."
