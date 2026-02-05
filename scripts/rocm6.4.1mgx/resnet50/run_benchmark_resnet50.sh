#!/bin/bash

# =============================================================================
# This script configures the environment and runs the MLPerf ResNet50
# inference benchmark with configurable scenario, category, and device settings.
#
# Usage:
#   HIP_VISIBLE_DEVICES=<id> ./run_benchmark.sh [--scenario <...>] [--category <...>]
#                                       [--device <...>] [--mode <...>]
#                                       [--framework <...>] [--log_path <...>]
#                                       [--count <...>] [--min_query_count <...>]
#                                       [--max_query_count <...>] [--time <...>]
#                                       [--performance_sample_count <...>]
#
# Example:
#   HIP_VISIBLE_DEVICES=1 ./run_benchmark.sh --scenario SingleStream --mode accuracy
# =============================================================================

# ---------------------------------
# Color definitions
# ---------------------------------
BLBlue='\033[1;34m'
BYellow='\033[1;33m'
BRed='\033[1;31m'
BGreen='\033[1;32m'
NC='\033[0m' # No Color

# ---------------------------------
# Script header information
# ---------------------------------
echo -e "============================== ${BYellow}Script Info${NC} =============================="
echo -e "${BYellow}Author: ${BLBlue}Nikola Catic @HTEC${NC}"
echo -e "${BYellow}Date: ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description: ${BLBlue}Run MLPerf ResNet50 Inference benchmark${NC}"
echo "=========================================================================="

echo -e "${BGreen}[IMPORTANT]:${NC} Inspect GPU usage and run the script with ${BYellow}HIP_VISIBLE_DEVICES=${BLBlue}[number]${NC}!"

# ---------------------------------
# Function to show usage
# ---------------------------------
usage() {
    echo -e "${BGreen}[USAGE]${NC}: ${BYellow}HIP_VISIBLE_DEVICES=${BLBlue}<device_id>${NC} $0 \\"
    echo -e "    [${BYellow}--scenario ${BLBlue}<SingleStream|MultiStream|Offline|Server>${NC}] \\"
    echo -e "    [${BYellow}--category ${BLBlue}<edge|datacenter>${NC}] \\"
    echo -e "    [${BYellow}--device ${BLBlue}<cpu|gpu|rocm>${NC}] \\" 
    echo -e "    [${BYellow}--model_name ${BLBlue}<resnet|resnet50>${NC}] \\"
    echo -e "    [${BYellow}--mode ${BLBlue}<accuracy|performance>${NC}] \\"
    echo -e "    [${BYellow}--framework ${BLBlue}<onnxruntime>${NC}] \\"
    echo -e "    [${BYellow}--log_path ${BLBlue}<output path>${NC}] \\"
    echo -e "    [${BYellow}--count ${BLBlue}<number>${NC}] \\"
    echo -e "    [${BYellow}--min_query_count ${BLBlue}<number>${NC}] \\"
    echo -e "    [${BYellow}--max_query_count ${BLBlue}<number>${NC}] \\"
    echo -e "    [${BYellow}--time ${BLBlue}<seconds>${NC}] \\"
    echo -e "    [${BYellow}--performance_sample_count ${BLBlue}<number>${NC}]"
    exit 1
}

# ---------------------------------
# Default parameter values
# ---------------------------------
scenario=SingleStream       # Benchmark scenario (SingleStream, MultiStream, Offline, Server)
category=edge               # Target category (edge or datacenter)
device=rocm                 # Execution device: cpu, gpu, or rocm
model_name=resnet50         # Machine Learning model: resnet50
framework=onnxruntime       # Framework used: pytorch
log_path=""                 # Output Path
mode=performance            # Mode used: accuracy, performance
min_query_count=""          # Minmimum Querry Count (available if count is set)
max_query_count=""          # Maximum Querry Count (available if count is set)
count=""                    # Dataset Items to use
time=""                     # Time to scan in seconds, sets min_duration="" max_duration=""
performance_sample_count="" # Sets performance sample count

# ---------------------------------
# Parse command-line arguments
# ---------------------------------

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --scenario)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                scenario="$2"; shift 2;
            fi;;
        --model_name)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                model_name="$2"; shift 2
            fi;;

        --category)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                category="$2"; shift 2
            fi;;

        --device)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value ${device}."
            else
                device="$2"; shift 2
            fi;;

        --mode)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                mode="$2"; shift 2
            fi;;
    
        --framework)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                framework="$2"; shift 2
            fi;;

        --log_path)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}Sets the $1 to default value${NC}."
            else
                log_path="$2"; shift 2
            fi;;

        --count)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --count"
                exit 1
            fi
            count="--count $2"; shift 2;;
        --min_query_count)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --min_query_count"
                exit 1
            fi
            min_query_count="--min_query_count $2"; shift 2;;
        --max_query_count)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --max_query_count"
                exit 1
            fi
            max_query_count="--max_query_count $2"; shift 2;;
        --time)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --time"
                exit 1
            fi
            time="--time $2"; shift 2;;
        --performance_sample_count)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --performance_sample_count"
                exit 1
            fi
            performance_sample_count="--performance_sample_count $2"; shift 2;;
        --h)
            usage;;
        --help)
            usage;;
        *)
            echo -e "${BRed}[ERROR]${NC} Unknown argument: $1"
            usage
            exit 1;;
    esac
done

# Normalize GPU keyword
if [ "$device" == "gpu" ]; then
    device="rocm"
    echo -e "${BGreen}[INFO]:${NC} GPU selected, using ROCm backend."
fi

# Normalize resnet keyword
if [ "$model_name" == "resnet" ]; then
    model_name="resnet50"
    echo -e "${BGreen}[INFO]:${NC} Model selected, using ResNet50 model."
fi

# Normalize path keyword
if [[ -z "$log_path" ]]; then
    log_path="/root/inference/vision/classification_and_detection/results/${model}/${scenario}/${category}/${mode}/"
fi


# ---------------------------------
# Display final configuration
# ---------------------------------

echo -e "${BGreen}[INFO]:${NC} Running MLPerf Benchmark with parameters:\n" \
        "  model_name  = ${BYellow}$model_name${NC}\n" \
        "  scenario    = ${BYellow}$scenario${NC}\n" \
        "  category    = ${BYellow}$category${NC}\n" \
        "  framework   = ${BYellow}$framework${NC}\n" \
        "  device      = ${BYellow}$device${NC}\n" \
        "  mode        = ${BYellow}${mode:-performance}${NC}\n" \
        "  log_path    = ${BYellow}${log_path}${NC}\n" \
        "  min_query_count = ${BYellow}${min_query_count:-Not Set}${NC}\n" \
        "  max_query_count = ${BYellow}${max_query_count:-Not Set}${NC}\n" \
        "  count       = ${BYellow}${count:-Not Set}${NC}\n" \
        "  time        = ${BYellow}${time:-Not Set}${NC}\n" \
        "  performance_sample_count = ${BYellow}${performance_sample_count:-Not Set}${NC}\n"

# Normalize mode keyword
if [[ "$mode" == "performance" || -z "$mode" ]]; then
    mode=""
else
    mode="--accuracy"
fi

# ---------------------------------
# Setup Python virtual environment
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Activating Python virtual environment."
cd /root/
source .venv/bin/activate

# ---------------------------------
# Configure ROCm graphics override (if using ROCm)
# ---------------------------------
# Extract the GFX version from rocminfo
if [ -z "${HIP_VISIBLE_DEVICES}" ]; then
    gpu_index=0
else 
    gpu_index=${HIP_VISIBLE_DEVICES}  # replace with your HIP_VISIBLE_DEVICES index (e.g., 0, 1, 2, ...)
fi  

gfx_versions=($(rocminfo | grep -Po '\bgfx[0-9]{3,}\b' | sed 's/gfx//')) 
gpu_names=($(rocminfo | grep -Po '(?<=Radeon RX).*'))

selected_gfx_version=${gfx_versions[$((gpu_index * 2))]}
selected_gpu_name=${gpu_names[$((gpu_index))]}${gpu_names[$((gpu_index+1))]}
echo -e "${BLBlue}[NOTE]:${NC} Selected gfx version for GPU ${BYellow}$gpu_index${NC}: ${BYellow}$selected_gfx_version${NC}"
echo -e "${BLBlue}[NOTE]:${NC} GPU name for GPU ID${BYellow}$gpu_index${NC}: ${BYellow}$selected_gpu_name${NC}"

# Compare with 1031
if [ "$selected_gfx_version" == "1031" ]; then
    echo -e "${BLBlue}[NOTE]:${NC} GFX version is 1031."
    echo -e "${BYellow}[NOTE]:${NC} Setting HSA_OVERRIDE_GFX_VERSION for ROCm compatibility..."
    export HSA_OVERRIDE_GFX_VERSION=10.3.0
    selected_gfx_version=1030
else
    echo -e "${BLBlue}[NOTE]:${NC} No need to override GFX version, the version is $selected_gfx_version."
fi

# ---------------------------------
# Run the MLPerf benchmark
# ---------------------------------

export MODEL_DIR=/model/resnet50_v1.onnx
export DATA_DIR=/dataset/imagenet/
export LOG_PATH=${log_path}

if [ "$selected_gpu_name" == "7900XT" ]; then
    USER_CONF=/root/inference/vision/classification_and_detection/user_gfx${selected_gfx_version}xt.conf
elif [ "$selected_gpu_name" == "7900XTX" ]; then
    USER_CONF=/root/inference/vision/classification_and_detection/user_gfx${selected_gfx_version}xtx.conf
else
    USER_CONF=/root/inference/vision/classification_and_detection/user_gfx${selected_gfx_version}.conf
fi

# Check if file exists
if [ ! -f "$USER_CONF" ]; then
    echo -e "${BLBlue}[NOTE]:${NC} Copying user.conf file: ${BYellow}$USER_CONF${NC}"
    cp /root/inference/vision/classification_and_detection/user.conf $USER_CONF
else
    echo -e "${BLBlue}[NOTE]:${NC} File already exists: ${BYellow}$USER_CONF${NC}"
fi

cd /root/inference/vision/classification_and_detection/
echo -e "${BLBlue}[NOTE]:${NC} Launching MLPerf inference benchmark..."

mkdir -p "${log_path}"

python python/main.py \
    ${mode} \
    --scenario ${scenario} \
    --backend ${framework} \
    --model-name ${model_name} \
    --device ${device} \
    --dataset-path ${DATA_DIR} \
    --model ${MODEL_DIR} \
    --user_conf ${USER_CONF} \
    --output $log_path \
    $count \
    $min_query_count \
    $max_query_count \
    $time \
    $performance_sample_count 2>&1 | tee ${log_path}/results.txt

if [[ $? -eq 0 ]]; then
    echo -e "${BGreen}[INFO]${NC} Benchmark finished successfully."
else
    echo -e "${BRed}[ERROR]${NC} Benchmark failed with exit code $?."
    #exit 1
fi

# ---------------------------------
# Completion message
# ---------------------------------

echo -e "================================= ${BYellow}Script finished${NC} ================================="
