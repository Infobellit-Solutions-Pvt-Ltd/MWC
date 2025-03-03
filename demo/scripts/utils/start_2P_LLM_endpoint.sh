#!/bin/bash

LOG_FILE="${HOME}/demo/logs/startup.log"
LLM_LOG_FILE="${HOME}/demo/logs/LLM_logs.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$LLM_LOG_FILE")"

echo "" >> "$LOG_FILE"
echo "==== Starting LLM containers on 2P Server ====" >> "$LOG_FILE"
echo "Script started at: $(date)" >> "$LOG_FILE"

echo "Generating the docker-compose.yml and haproxy.cfg files for Deepseek" >> "$LLM_LOG_FILE" 2>&1
ssh -q -o "LogLevel=ERROR" -t 2p << 'EOF' >> "$LLM_LOG_FILE" 2>&1

  # Use absolute path to source parameters on the remote server
  echo "Sourcing parameters file..."
  source "./demo/scripts/parameters.sh"

  # Default REPLICAS from parameter.sh (can be overridden by CLI)
  REPLICAS=$DOCKER_COMP_NUM_CONTAINERS_2P_LLM

  # CPU pinning sets
  CCD_CORES_PINNING_LIST=(
    "0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100,102,104,106,108,110,112,114,116,118,120,122,124,126"
    "128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,158,160,162,164,166,168,170,172,174,176,178,180,182,184,186,188,190,192,194,196,198,200,202,204,206,208,210,212,214,216,218,220,222,224,226,228,230,232,234,236,238,240,242,244,246,248,250,252,254"
    "256,258,260,262,264,266,268,270,272,274,276,278,280,282,284,286,288,290,292,294,296,298,300,302,304,306,308,310,312,314,316,318,320,322,324,326,328,330,332,334,336,338,340,342,344,346,348,350,352,354,356,358,360,362,364,366,368,370,372,374,376,378,380,382"
    "384,386,388,390,392,394,396,398,400,402,404,406,408,410,412,414,416,418,420,422,424,426,428,430,432,434,436,438,440,442,444,446,448,450,452,454,456,458,460,462,464,466,468,470,472,474,476,478,480,482,484,486,488,490,492,494,496,498,500,502,504,506,508,510"
  )

  # Define compose directory (use an absolute path on the remote server)
  COMPOSE_DIR="./demo/docker_compose/DS"
  mkdir -p "$COMPOSE_DIR"

  echo "Generating docker-compose.yml..."
  cat > "$COMPOSE_DIR/docker-compose.yml" <<EOL
# version: '3.8'

services:
EOL

  # Create vLLM services dynamically
  for (( i=1; i<=REPLICAS; i++ )); do
      CONTAINER_NAME="deepseek1.5b-${i}"
      SERVICE_NAME="vllm${i}"

      if [[ $i -le ${#CCD_CORES_PINNING_LIST[@]} ]]; then
          CPU_CORES="${CCD_CORES_PINNING_LIST[$((i-1))]}"
      else
          echo "Error: Not enough CPU pinning sets for replicas."
          exit 1
      fi

      cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL
    ${SERVICE_NAME}:
      image: ${LLM_DEPLOY_DI}
      container_name: ${CONTAINER_NAME}
      environment:
        - HUGGING_FACE_HUB_TOKEN=${LLM_HF_TOKEN}
      volumes:
        - ${LLM_DS_MODEL_LOCATION}:/deepseek1.5b
      cpuset: "${CPU_CORES}"
      mem_limit: "48g"
      command: ["--model", "/deepseek1.5b"]
      networks:
        - vllm_network
EOL
  done

  # Add HAProxy service
  cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL

    haproxy:
      image: haproxy:2.8
      container_name: haproxy_deepseek
      ports:
        - "${LLM_DS_HOST_PORT}:${LLM_DS_HOST_PORT}"
      volumes:
        - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
      depends_on:
EOL

    for (( i=1; i<=REPLICAS; i++ )); do
        echo "        - vllm${i}" >> "$COMPOSE_DIR/docker-compose.yml"
    done

    cat >> "$COMPOSE_DIR/docker-compose.yml" <<EOL
      networks:
        - vllm_network

networks:
  vllm_network:
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
  bind *:${LLM_DS_HOST_PORT}
  default_backend model_backend

backend model_backend
  balance roundrobin
EOL

  # Add backend servers dynamically for each replica
  for (( i=1; i<=REPLICAS; i++ )); do
      echo "  server vllm${i} vllm${i}:8000 check" >> "$COMPOSE_DIR/haproxy.cfg"
  done

  echo "Generated docker_compose/DS/haproxy.cfg"

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

echo "Files generated successfully. Starting the Deepseek containers on 2P server." >> "$LLM_LOG_FILE" 2>&1
ssh -q -o "LogLevel=ERROR" -t 2p "cd ./demo/docker_compose/DS && docker-compose up -d"  >> "$LLM_LOG_FILE" 2>&1


ssh -q -o "LogLevel=ERROR" -t 2p << 'EOF' >> "$LLM_LOG_FILE" 2>&1

    source "./demo/scripts/parameters.sh"

    # Default REPLICAS from parameter.sh (can be overridden by CLI)
    REPLICAS=$DOCKER_COMP_NUM_CONTAINERS_2P_LLM

    echo "Deployment started with $REPLICAS replicas"
    echo "Sleeping for 10 seconds"
    sleep 10

    # # Check if all containers are running
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "deepseek1.5b-[0-9]+" | wc -l)

    if [[ "$RUNNING_CONTAINERS" -eq "$REPLICAS" ]]; then
        echo "✅ $REPLICAS Deepseek1.5b containers are running successfully!"
    else
        echo "❌ Warning: Some Deepseek1.5b containers might have failed to start!"
        docker ps -a
        exit 1
    fi

EOF
echo "==== Deployment Script Completed on 2P Server ====" >> "$LOG_FILE"