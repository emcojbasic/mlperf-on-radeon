#!/bin/bash

# =============================================================================
# This script configures the environment,
# and runs the MLPerf BERT inference benchmark with configurable
# scenario, category, and device settings.
#
# Usage: ./run_benchmark.sh --model [bert|bert-99] \
#                           --scenario [SingleStream|MultiStream|Offline|Server] \
#                           --category [edge|datacenter] \
#                           --device [cpu|gpu|rocm] \
#                           --mode [accuracy|performance]
# Example: ./run_benchmark.sh --model bert --scenario SingleStream --category edge --mode accuracy
# =============================================================================

# Color definitions
BLBlue='\033[1;34m'    # Bold Light Blue
BYellow='\033[1;33m'    # Bold Yellow
BRed='\033[1;31m'    # Bold Red
BGreen='\033[1;32m'       # Bold Green
NC='\033[0m'            # No Color (reset)

# Function to display usage
usage() {
    echo -e "${BGreen}[USAGE]${NC}: ${BYellow}HIP_VISIBLE_DEVICES=${BLBlue}<device_id>${NC} $0 \
    [${BYellow}--model ${BLBlue}<bert|bert-99>${NC}] \
    [${BYellow}--category ${BLBlue}<edge|datacenter>${NC}] \
    [${BYellow}--scenario ${BLBlue}<SingleStream|MultiStream|Offline|Server>${NC}] \
    [${BYellow}--device ${BLBlue}<cpu|gpu|rocm>${NC}] \
    [${BYellow}--mode ${BLBlue}<accuracy|performance>${NC}] \
    [${BYellow}--network ${BLBlue}<"sut"|"lon"|None>${NC}] \
    [${BYellow}--sut_server ${BLBlue}<http://localhost:8000>${NC}] \
    [${BYellow}--max_examples ${BLBlue}<Set a number>${NC}] \
    [${BYellow}--node ${BLBlue}<>${NC}] \
    [${BYellow}--port ${BLBlue}<8000>${NC}]"
    exit 1
}

# ---------------------------------
# Script header information
# ---------------------------------
echo -e "============================== ${BYellow}Script Info${NC} =============================="
echo -e "${BYellow}Author: ${BLBlue}Nikola Catic, Emilija Cojbasic @HTEC${NC}"
echo -e "${BYellow}Date: ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description: ${BLBlue}Run MLPerf BERT Inference benchmark${NC}"
echo "=========================================================================="

echo -e "${BGreen}[IMPORTANT]:${NC} Inspect GPU usage and run the script with ${BYellow}HIP_VISIBLE_DEVICES=${BLBlue}[number]${NC}!"

# ---------------------------------
# Default parameter values
# ---------------------------------
scenario=SingleStream       # Benchmark scenario (SingleStream, MultiStream, Offline, Server)
category=datacenter         # Target category (edge or datacenter)
device=gpu                  # Execution device: cpu, gpu, or rocm
model=bert-99               # Machine Learning model: bert
framework=pytorch           # Framework used: pytorch
log_path=""                 # Output Path
max_examples=""             # Maximum number of examples to consider (not limited by default)
network=""                  # Loadgen network mode ["sut", "lon", None]
node=""                     # default=""
port=""                     # port=8000
sut_server=""               # Address of the server(s) under test. default=["http://localhost:8000"]
mode=performance            # Mode used: accuracy, performance

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
        --model)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                model="$2"; shift 2
            fi;;

        --category)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
            else
                category="$2"; shift 2
            fi;;

        --device)
            echo -e "${BRed}[ERROR:]${NC} Setting device is not available!"
            exit 1
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BYellow}[Default]${NC} Sets the $1 to default value."
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

        --max_examples)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --max_examples"
                exit 1
            fi
            max_examples="--max_examples $2"; shift 2;;

        --network)
            if [[ -z "$2" || "$2" == --* ]]; then
                network="--network None"; shift 1;
            else
                network="--network $2"; shift 2;
            fi;;

        --node)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${BRed}[ERROR]${NC} Missing value for --node"
                exit 1
            fi
            node="--node $2"; shift 2;;

        --port)
            if [[ -z "$2" || "$2" == --* ]]; then
                port="--port 8000"; shift 1;
            else
                port="--port $2"; shift 2;
            fi;;

        --sut_server)
            if [[ -z "$2" || "$2" == --* ]]; then
                sut_server="--sut_server http://localhost:8000"; shift 1;
            else
                sut_server="--sut_server $2"; shift 2;
            fi;;
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
    device=""
    echo -e "${BGreen}[INFO]:${NC} GPU selected, using ROCm backend."
fi
if [ "$device" == "rocm" ]; then
    device=""
    echo -e "${BGreen}[INFO]:${NC} GPU selected, using ROCm backend."
fi

# Normalize bert keyword
if [ "$model" == "bert-99" ]; then
    model="bert"
    echo -e "${BGreen}[INFO]:${NC} Model selected, using BERT-99 model."
fi

# Normalize GPU keyword to ROCm
if [ "$device" == "cpu" ]; then
    device="HIP_VISIBLE_DEVICES=\"\""
    echo -e "${BGreen}[INFO]:${NC} CPU selected, using CPU backend."
    # TODO: find the bug in MLPerf inference bert running with env variable enabled
    echo -e "${BRed}[ERROR]:${NC} There is a bug in repo when running on CPU. Exiting the script!"
    exit 1
fi

# Normalize path keyword
if [[ -z "$log_path" ]]; then
    log_path="/root/inference/language/bert/results/${scenario}/${category}/${mode}/"
fi


# ---------------------------------
# Display final configuration
# ---------------------------------
echo -e "${BGreen}[INFO]:${NC} Running MLPerf Benchmark with parameters:\n" \
        "  model       = ${BYellow}$model${NC}\n" \
        "  scenario    = ${BYellow}$scenario${NC}\n" \
        "  category    = ${BYellow}$category${NC}\n" \
        "  framework   = ${BYellow}$framework${NC}\n" \
        "  device      = ${BYellow}OPTION NOT AVAILABLE${NC}\n" \
        "  mode        = ${BYellow}$mode${NC}\n" \
        "  log_path    = ${BYellow}$log_path${NC}\n" \
        "  max_examples= ${BYellow}${max_examples:-Not Set}${NC}\n" \
        "  network     = ${BYellow}${network:-Not Set}${NC}\n" \
        "  node        = ${BYellow}${node:-Not Set}${NC}\n" \
        "  port        = ${BYellow}${port:-Not Set}${NC}\n" \
        "  sut_server  = ${BYellow}${sut_server:-Not Set}${NC}"

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

echo -e "${BLBlue}[NOTE]:${NC} Selected gfx version for GPU ID${BYellow}$gpu_index${NC}: ${BYellow}$selected_gfx_version${NC}"
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

export ML_MODEL_FILE_WITH_PATH=/model/model.pytorch
export VOCAB_FILE=/model/vocab.txt
export DATASET_FILE=/data/validation/dev-v1.1.json
export LOG_PATH=${log_path}

if [ "$selected_gpu_name" == "7900XT" ]; then
    USER_CONF=/root/inference/language/bert/user_gfx${selected_gfx_version}xt.conf
elif [ "$selected_gpu_name" == "7900XTX" ]; then
    USER_CONF=/root/inference/language/bert/user_gfx${selected_gfx_version}xtx.conf
else
    USER_CONF=/root/inference/language/bert/user_gfx${selected_gfx_version}.conf
fi

# Check if file exists
if [ ! -f "$USER_CONF" ]; then
    echo -e "${BLBlue}[NOTE]:${NC} Copying user.conf file: ${BYellow}$USER_CONF${NC}"
    cp /root/inference/language/bert/user.conf $USER_CONF
else
    echo -e "${BLBlue}[NOTE]:${NC} File already exists: ${BYellow}$USER_CONF${NC}"
fi

cd /root/inference/language/bert/
echo -e "${BLBlue}[NOTE]:${NC} Launching MLPerf inference benchmark..."

if [ "$mode" == "--accuracy" ]; then
    export SKIP_VERIFY_ACCURACY=1
    echo -e "${BLBlue}[NOTE]:${NC} Set ${BYellow}SKIP_VERIFY_ACCURACY=1${NC} environment variable launch due to invalid path. The script will run after the benchmark finishes."
fi

mkdir -p "${log_path}"

python ./run.py  --backend $framework \
    ${mode} \
    --scenario $scenario \
    --user_conf ${USER_CONF} \
    ${max_examples} \
    ${port} \
    ${node} \
    ${network} \
    ${sut_server} 2>&1 | tee ${log_path}/results.txt

if [[ $? -eq 0 ]]; then
    echo -e "${BGreen}[INFO]${NC} Benchmark finished successfully."
else
    echo -e "${BRed}[ERROR]${NC} Benchmark failed with exit code $?."
    #exit 1
fi

# ---------------------------------
# Run the MLPerf Accuracy if set
# --------------------------------- 
mkdir -p ${log_path}/evaluated_accuracy/

if [ "$mode" == "--accuracy" ]; then
    python ./accuracy-squad.py --vocab_file ${VOCAB_FILE} --val_data ${DATASET_FILE} --log_file ${log_path}/mlperf_log_accuracy.json --out_file ${log_path}/evaluated_accuracy/evaluated.log ${max_examples}
    if [[ $? -eq 0 ]]; then
        echo -e "${BGreen}[INFO]${NC} Accuracy Evaluation finished successfully."
    else
        echo -e "${BRed}[ERROR]${NC} Accuracy Evaluation failed with exit code $?."
        #exit 1
    fi
fi

# ---------------------------------
# Completion message
# ---------------------------------

echo -e "================================= ${BYellow}Script finished${NC} ================================="