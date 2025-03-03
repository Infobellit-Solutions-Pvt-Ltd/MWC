#!/bin/bash

LOG_FILE="${HOME}/demo/logs/startup.log"
VIT_LOG_FILE="${HOME}/demo/logs/VIT_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$VIT_log_file")"

echo "" >> "$LOG_FILE"
echo "==== Starting VIT Service on 2P Server ====" >> "$LOG_FILE"
echo "Script started at: $(date)" >> "$LOG_FILE"

echo "Generating the docker-compose.yml and haproxy.cfg files for VIT" >> "$VIT_LOG_FILE" 2>&1
ssh -q -o "LogLevel=ERROR" -t 2p << 'EOF' >> "$VIT_LOG_FILE" 2>&1

  # Use absolute path to source parameters on the remote server
  echo "Sourcing parameters file..."
  source "./demo/scripts/parameters.sh"

  # Default REPLICAS from parameter.sh (can be overridden by CLI)
  REPLICAS=$DOCKER_COMP_NUM_CONTAINERS_2P_VIT

  # CPU pinning sets
  CCD_CORES_PINNING_LIST=(
        "3,5,11,13,19,21,27,29,35,37,43,45,51,53,59,61,67,69,75,77,83,85,91,93,99,101,107,109,115,117,123,125"
        "131,133,139,141,147,149,155,157,163,165,171,173,179,181,187,189,195,197,203,205,211,213,219,221,227,229,235,237,243,245,251,253"
        "257,261,265,269,273,277,281,285,289,293,297,301,305,309,313,317,321,325,329,333,337,341,345,349,353,357,361,365,369,373,377,381"
        "385,389,393,397,401,405,409,413,417,421,425,429,433,437,441,445,449,453,457,461,465,469,473,477,481,485,489,493,497,501,505,509"
        "259,263,267,271,275,279,283,287,291,295,299,303,307,311,315,319,323,327,331,335,339,343,347,351,355,359,363,367,371,375,379,383"
        "387,391,395,399,403,407,411,415,419,423,427,431,435,439,443,447,451,455,459,463,467,471,475,479,483,487,491,495,499,503,507,511"
    )

  # Define compose directory (use an absolute path on the remote server)
  COMPOSE_DIR="./demo/docker_compose/VIT"
  mkdir -p "$COMPOSE_DIR"

  echo "Generating docker-compose.yml..."
  cat > "$COMPOSE_DIR/docker-compose.yml" <<EOL
# version: '3.8'

services:
EOL

  # Create vLLM services dynamically
  for (( i=1; i<=REPLICAS; i++ )); do
      CONTAINER_NAME="vit-${i}"
      SERVICE_NAME="vit${i}"

      if [[ $i -le ${#CCD_CORES_PINNING_LIST[@]} ]]; then
          CPU_CORES="${CCD_CORES_PINNING_LIST[$((i-1))]}"
      else
          echo "Error: Not enough CPU pinning sets for replicas."
          exit 1
      fi

      cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL
    ${SERVICE_NAME}:
      image: ${VIT_DEPLOY_DI}
      container_name: ${CONTAINER_NAME}
      environment:
        CPU_BIND: "${CPU_CORES}"
      deploy:
        resources:
          limits:
            memory: 48g
      networks:
        - vit_network
EOL
  done

  # Add HAProxy service
  cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL

    haproxy:
      image: haproxy:2.8
      container_name: haproxy_vit
      ports:
        - "${VIT_HOST_PORT}:${VIT_HOST_PORT}"
      volumes:
        - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      depends_on:
EOL

    for (( i=1; i<=REPLICAS; i++ )); do
        echo "        - vit${i}" >> "$COMPOSE_DIR/docker-compose.yml"
    done

    cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL
      networks:
        - vit_network

networks:
  vit_network:
    name: vit_network
    driver: bridge
EOL

  echo "Generated HAProxy service in docker-compose.yml."

  # Generate HAProxy configuration
  cat > "$COMPOSE_DIR/haproxy.cfg" <<EOL
global
    log stdout format raw local0

defaults
    log     global
    mode    http
    option  httplog
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend http_front
  bind *:${VIT_HOST_PORT}
  default_backend model_backend

backend model_backend
  balance roundrobin
EOL

  # Add backend servers dynamically for each replica
  for (( i=1; i<=REPLICAS; i++ )); do
      echo "  server vit-${i} vit-${i}:8080 check" >> "$COMPOSE_DIR/haproxy.cfg"
  done

  echo "Generated docker_compose/VIT/haproxy.cfg"

  # Ensure docker-compose.yml was generated
  if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
      echo "Error: docker-compose.yml was not generated successfully."
      exit 1
  fi

  # Ensure haproxy.cfg was generated
  if [[ ! -f "$COMPOSE_DIR/haproxy.cfg" ]]; then
      echo "Error: haproxy.cfg was not generated successfully."
      exit 1
  fi


EOF

echo "Files generated successfully. Starting the VIT containers on 2P server." >> "$VIT_LOG_FILE" 2>&1
ssh -q -o "LogLevel=ERROR" -t 2p "cd ./demo/docker_compose/VIT && docker-compose up -d"  >> "$VIT_LOG_FILE" 2>&1


ssh -q -o "LogLevel=ERROR" -t 2p << 'EOF' >> "$VIT_LOG_FILE" 2>&1

    source "./demo/scripts/parameters.sh"

    # Default REPLICAS from parameter.sh 
    REPLICAS=$DOCKER_COMP_NUM_CONTAINERS_2P_VIT

    echo "Deployment started with $REPLICAS replicas"
    echo "Sleeping for 10 seconds"
    sleep 10

    # # Check if all containers are running
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "vit-[0-9]+" | wc -l)

    if [[ "$RUNNING_CONTAINERS" -eq "$REPLICAS" ]]; then
        echo "✅ $REPLICAS VIT containers are running successfully!"
    else
        echo "❌ Warning: Some VIT containers might have failed to start!"
        docker ps -a
    fi

EOF
echo "==== Deployment Script Completed on 2P Server ====" >> "$LOG_FILE"