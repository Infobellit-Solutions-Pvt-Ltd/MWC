# Stop Loadgen 

docker stop 1P_loadgen_DS 1P_loadgen_vit 
docker stop 2P_loadgen_DS 2P_loadgen_vit
docker stop 2PC_loadgen_DS 2PC_loadgen_vit

# Stop Power and system
./utils/scripts_sys_metrics/stop-system-metrics.sh
./utils/power_metrics/stop-power-data.sh

# Stop Workloads

ssh 1p "docker stop 1P_DS-1.5b "
# 1P_loadgen_VIT
ssh 1p "cd ./demo/docker_compose/VIT && docker-compose down"
ssh 2p "cd ./demo/docker_compose/VIT && docker-compose down"
ssh 2p "cd ./demo/docker_compose/DS && docker-compose down"

ssh 2pc_b "cd ./demo/docker_compose/VIT && docker-compose down"
ssh 2pc_a "cd ./demo/docker_compose/DS && docker-compose down"

