#!/bin/bash

# LOG_FILE="${HOME}/demo/logs/bin.log"

# # Ensure log directory exists
# mkdir -p "$(dirname "$LOG_FILE")"

run_ssh_command() {
    local host=$1
    local script=$2
 
    # Run SSH and capture output while suppressing MOTD
    # ssh -q -o "LogLevel=ERROR" -t "$host" "$script" 2>&1 | tee -a "$LOG_FILE" | grep -v -E "^(Welcome to|System information as of|Documentation:|Support:|Management:|Expanded Security Maintenance|updates can be applied|Last login:)"
    ssh -q -o "LogLevel=ERROR" -t "$host" "$script" 2>&1 | grep -v -E "^(Welcome to|System information as of|Documentation:|Support:|Management:|Expanded Security Maintenance|updates can be applied|Last login:)"
    #echo "✅ Logs saved to $log_file"
}
 
 
# Define the checks for each host
script_1p='
  echo -e "\e[1;92m----------------------- Checking workload containers on 1P server -----------------------\e[0m"
  #Deepseek model
  if docker ps --format "{{.Names}}" | grep -q "^1P_DS-1.5b$"; then
      echo -e "\e[1;32m✅ Deepseek1.5b container is running.\e[0m"
  else
      echo -e "\e[1;31m❌ ERROR: Deepseek1.5b container failed to start!\e[0m"
  fi
  
  #VIT model
  vit_count=$(docker ps --format "{{.Names}}" | grep -Ec "vit-[0-9]+")

  if [[ $vit_count -gt 0 ]]; then
        echo -e "\e[1;32m✅ $vit_count VIT containers are running.\e[0m"
  else
        echo -e "\e[1;31m❌ ERROR: VIT failed to start!\e[0m"
  fi
  docker ps
  echo ""

'
 
script_2p='
    echo -e "\e[1;92m----------------------- Checking workload containers on 2P server -----------------------\e[0m"

    deepseek_count=$(docker ps --format "{{.Names}}" | grep -Ec "deepseek1.5b-[0-9]+")
    vit_count=$(docker ps --format "{{.Names}}" | grep -Ec "vit-[0-9]+")
    
    if [[ $deepseek_count -gt 0 ]]; then
        echo -e "\e[1;32m✅ $deepseek_count Deepseek1.5b containers are running.\e[0m"
    else
        echo -e "\e[1;31m❌ ERROR: Deepseek1.5b container failed to start!\e[0m"
    fi
    
    if [[ $vit_count -gt 0 ]]; then
        echo -e "\e[1;32m✅ $vit_count VIT containers are running.\e[0m"
    else
        echo -e "\e[1;31m❌ ERROR: VIT failed to start!\e[0m"
    fi
    docker ps
    echo ""
'
 
script_2pc_a='
    echo -e "\e[1;92m----------------------- Checking workload containers on 2PC_A server -----------------------\e[0m"

    deepseek_count=$(docker ps --format "{{.Names}}" | grep -Ec "deepseek1.5b-[0-9]+")

    if [[ $deepseek_count -gt 0 ]]; then
        echo -e "\e[1;32m✅ $deepseek_count Deepseek1.5b containers are running.\e[0m"
    else
        echo -e "\e[1;31m❌ ERROR: Deepseek1.5b container failed to start!\e[0m"
    fi

    docker ps
    echo ""
'
 
script_2pc_b='
    echo -e "\e[1;92m----------------------- Checking workload containers on 2PC_B server -----------------------\e[0m"

    vit_count=$(docker ps --format "{{.Names}}" | grep -Ec "vit-[0-9]+")

    if [[ $vit_count -gt 0 ]]; then
        echo -e "\e[1;32m✅ $vit_count VIT containers are running.\e[0m"
    else
        echo -e "\e[1;31m❌ ERROR: VIT failed to start!\e[0m"
    fi

    docker ps
    echo ""
'
 
# Execute commands in parallel
run_ssh_command "1p" "$script_1p" &
sleep 1
 
run_ssh_command "2p" "$script_2p" &
sleep 1
 
run_ssh_command "2pc_a" "$script_2pc_a" &
sleep 1
 
run_ssh_command "2pc_b" "$script_2pc_b" &
sleep 1
# Wait for all SSH processes to complete
wait
# echo "✅ All checks completed!"