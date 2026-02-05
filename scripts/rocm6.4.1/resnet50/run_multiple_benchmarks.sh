#!/bin/bash

# =============================================================================
# MLPerf ResNet50 Inference Multi-GPU Runner
# =============================================================================
# This script configures the environment and runs MLPerf ResNet50 inference 
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
echo -e "${BYellow}Author     :${NC} ${BLBlue}Nikola Catic @HTEC${NC}"
echo -e "${BYellow}Date       :${NC} ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description:${NC} ${BLBlue}Run MLPerf ResNet50 Inference benchmark on multiple GPUs${NC}"
echo "==============================================================================="

echo -e "${BGreen}[IMPORTANT]${NC}: Set ${BYellow}HIP_VISIBLE_DEVICES${NC} if you want to manually control GPU visibility."

# ---------------------------------
# Default Parameters
# ---------------------------------
scenario=SingleStream               # Benchmark scenario (SingleStream, MultiStream, Offline, Server)
category=edge                       # Target category (edge or datacenter)
device=rocm                         # Execution device: cpu, gpu, or rocm
model_name=resnet50                 # Machine Learning model: resnet50
framework=onnxruntime               # Framework used: pytorch
log_path=""                         # Output Path
mode=performance                    # Mode used: accuracy, performance
min_query_count=""                  # Minmimum Querry Count (available if count is set)
max_query_count=""                  # Maximum Querry Count (available if count is set)
count=""                            # Dataset Items to use
time=""                             # Time to scan in seconds, sets min_duration="" max_duration=""
performance_sample_count=""         # Sets performance sample count
multiple_gpu_architecture_ids="0"   # Multiple GPUs architecture IDs that will be used

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
    IFS=$'\n' read -r -d '' -a gfx_versions < <(rocminfo | grep -Po '\bgfx[0-9]{3,}\b' | sed 's/gfx//' && printf '\0')
    
    local selected_gfx_version="${gfx_versions[$((gpu_index * 2))]}"

    echo -e "${BLBlue}[NOTE]${NC} Detected GFX version for GPU ${BYellow}${gpu_index}${NC}: ${BYellow}${selected_gfx_version}${NC}"

    gpu_names=($(rocminfo | grep -Po '(?<=Radeon RX).*'))
    selected_gpu_name=${gpu_names[$((gpu_index))]}${gpu_names[$((gpu_index+1))]}
    echo -e "${BLBlue}[NOTE]:${NC} GPU name for GPU ID${BYellow}$gpu_index${NC}: ${BYellow}$selected_gpu_name${NC}"

    # Apply GFX override if needed
    if [[ "$selected_gfx_version" == "1031" ]]; then
        echo -e "${BYellow}[NOTE]${NC} Applying ROCm compatibility override: HSA_OVERRIDE_GFX_VERSION=10.3.0"
        export HSA_OVERRIDE_GFX_VERSION="10.3.0"
    else
        unset HSA_OVERRIDE_GFX_VERSION
    fi

    # Set GPU visibility
    export HIP_VISIBLE_DEVICES="$gpu_index"

    # Run all benchmark scenarios/modes
    for s in SingleStream MultiStream Offline Server; do
        for m in performance accuracy; do
            echo -e "${BYellow}Running scenario=${s}, mode=${m}...${NC}"            
            if [ "$selected_gpu_name" == "7900XT" ]; then
                log_path="/root/inference/vision/classification_and_detection/results/GFX${selected_gfx_version}XT/${category}/${s}/${m}/"
            elif [ "$selected_gpu_name" == "7900XTX" ]; then
                log_path="/root/inference/vision/classification_and_detection/results/GFX${selected_gfx_version}XTX/${category}/${s}/${m}/"
            else
                log_path="/root/inference/vision/classification_and_detection/results/GFX${selected_gfx_version}/${category}/${s}/${m}/"
            fi

            bash ./run_benchmark.sh \
                --scenario "$s" \
                --category "$category" \
                --mode "$m" \
                --log_path "$log_path" \
                ${count:+--count "$count"} \
                ${min_query_count:+--min_query_count "$min_query_count"} \
                ${max_query_count:+--max_query_count "$max_query_count"} \
                ${time:+--time "$time"} \
                ${performance_sample_count:+--performance_sample_count "$performance_sample_count"} \
                --framework "$framework" \
                --model_name "$model_name"

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

# Wait for all background jobs
wait

echo -e "\n${BGreen}[DONE]${NC} All GPU benchmarks completed successfully!"
