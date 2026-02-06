#!/bin/bash

# =============================================================================
# MLPerf BERT Inference Multi-GPU Runner
# =============================================================================
# This script configures the environment and runs MLPerf BERT inference 
# benchmarks on multiple GPUs, using customizable scenario, category, and device.
# =============================================================================

# ---------------------------------
# Color Definitions
# ---------------------------------
BLBlue='\033[1;34m'
BYellow='\033[1;33m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
NC='\033[0m'

# ---------------------------------
# Usage Message
# ---------------------------------
usage() {
    echo -e "${BGreen}[USAGE]${NC}: $0 ${BYellow}--multiple_gpu_architecture_ids ${BLBlue}<comma_separated_ids>${NC}"
    exit 1
}

# ---------------------------------
# Script Info
# ---------------------------------
echo -e "============================ ${BYellow}Script Info${NC} ============================"
echo -e "${BYellow}Author     :${NC} ${BLBlue}Nikola Catic, Emilija Cojbasic @HTEC${NC}"
echo -e "${BYellow}Date       :${NC} ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description:${NC} ${BLBlue}Run MLPerf BERT Inference benchmark on multiple GPUs${NC}"
echo "==============================================================================="

echo -e "${BGreen}[IMPORTANT]${NC}: Set ${BYellow}HIP_VISIBLE_DEVICES${NC} if you want to manually control GPU visibility."

# ---------------------------------
# Default Parameters
# ---------------------------------
scenario="SingleStream"                 # Benchmark scenario (SingleStream, MultiStream, Offline, Server)
category="datacenter"                   # Target category (edge or datacenter)
device="gpu"                            # Execution device: cpu, gpu, or rocm
model="bert-99"                         # Machine Learning model: bert
framework="onnxruntime"                     # Framework used: pytorch
log_path=""                             # Output Path
max_examples=""                         # Maximum number of examples to consider (not limited by default)
network=""                              # Loadgen network mode ["sut", "lon", None]
node=""                                 # default=""
port=""                                 # default=8000
sut_server=""                           # Address of the server(s) under test. default=["http://localhost:8000"]
mode="performance"                      # Mode used: accuracy, performance
multiple_gpu_architecture_ids="0"       # Multiple GPUs architecture IDs that will be used

# ---------------------------------
# Parse Arguments
# ---------------------------------
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --multiple_gpu_architecture_ids)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --multiple_gpu_architecture_ids"
                usage
            fi
            multiple_gpu_architecture_ids="$2"
            shift 2
            ;;
        --h|--help)
            usage
            ;;
        *)
            echo -e "${BRed}[ERROR]${NC} Unknown argument: $1"
            usage
            ;;
    esac
done

# ---------------------------------
# Determine GPU IDs
# ---------------------------------
if [[ -z "${HIP_VISIBLE_DEVICES}" ]]; then
    IFS=',' read -r -a gpu_ids <<< "$multiple_gpu_architecture_ids"
    echo -e "${BGreen}[INFO]${NC} Using GPU IDs from --multiple_gpu_architecture_ids: ${gpu_ids[*]}"
else
    IFS=',' read -r -a gpu_ids <<< "$HIP_VISIBLE_DEVICES"
    echo -e "${BGreen}[INFO]${NC} Using GPU IDs from HIP_VISIBLE_DEVICES: ${gpu_ids[*]}"
fi

# ---------------------------------
# Run Benchmarks per GPU
# ---------------------------------
run_benchmark_for_gpu() {
    local gpu_index="$1"

    echo -e "\n${BGreen}[INFO]${NC} Running benchmarks on GPU ID: ${BLBlue}${gpu_index}${NC}"

    # Get ROCm gfx version
    local gfx_versions
    gfx_versions=($(rocminfo | grep -Po '\bgfx[0-9]{3,}\b' | sed 's/gfx//'))
    
    local selected_gfx_version=${gfx_versions[$((gpu_index * 2))]}
    echo -e "${BLBlue}[NOTE]${NC} Detected GFX version for GPU ${BYellow}${gpu_index}${NC}: ${BYellow}${selected_gfx_version}${NC}"

    gpu_names=($(rocminfo | grep -Po '(?<=Radeon RX).*'))
    selected_gpu_name=${gpu_names[$((gpu_index))]}${gpu_names[$((gpu_index+1))]}
    echo -e "${BLBlue}[NOTE]:${NC} GPU name for GPU ID${BYellow}$gpu_index${NC}: ${BYellow}$selected_gpu_name${NC}"

    # Set GPU visibility
    export HIP_VISIBLE_DEVICES="$gpu_index"

    # Run all benchmark scenarios/modes
    for s in SingleStream MultiStream Offline Server; do
        for m in performance accuracy; do
            echo -e "${BYellow}Running scenario=${s}, mode=${m}...${NC}"

            if [ "$selected_gpu_name" == "7900XT" ]; then
                log_path="/root/inference/language/bert/results/GFX${selected_gfx_version}XT/${category}/${s}/${m}/"
            elif [ "$selected_gpu_name" == "7900XTX" ]; then
                log_path="/root/inference/language/bert/results/GFX${selected_gfx_version}XTX/${category}/${s}/${m}/"
            else
                log_path="/root/inference/language/bert/results/GFX${selected_gfx_version}/${category}/${s}/${m}/"
            fi

            bash ./run_benchmark_bert.sh \
                --scenario "$s" \
                --category "$category" \
                --mode "$m" \
                --log_path "$log_path" \
                ${network:+--network "$network"} \
                ${node:+--node "$node"} \
                ${port:+--port "$port"} \
                ${sut_server:+--sut_server "$sut_server"} \
                --framework "$framework" \
                --model "$model" 

            # Exit if a benchmark fails
            local exit_code=$?
            if [[ $exit_code -ne 0 ]]; then
                echo -e "${BRed}[ERROR]${NC} Benchmark failed (scenario=$s, mode=$m) with exit code $exit_code for GPU ID ${gpu_index}"
                #return $exit_code
            fi
        done
    done

    echo -e "${BGreen}[INFO]${NC} Completed all benchmarks for GPU ID ${gpu_index}"
    echo -e "${BYellow}-------------------------------------------------------------${NC}"
}

# Main execution loop
for gpu_index in "${gpu_ids[@]}"; do
    run_benchmark_for_gpu "$gpu_index" &
done

wait

echo -e "\n${BGreen}[DONE]${NC} All GPU benchmarks completed successfully!"
