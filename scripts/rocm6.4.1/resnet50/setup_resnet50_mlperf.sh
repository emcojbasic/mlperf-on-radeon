#!/bin/bash

# =============================================================================
# This script installs dependencies and configures the environment
# for ResNet50 benchmarking with MLPerf.
#
# Usage: ./setup_resnet50_mlperf.sh
# =============================================================================
# -----------------------------
# Color definitions
# -----------------------------
BLBlue='\033[1;34m'    # Bold Light Blue
BYellow='\033[1;33m'    # Bold Yellow
BRed='\033[1;31m'    # Bold Red
BGreen='\033[1;32m'       # Bold Green
NC='\033[0m'            # No Color (reset)

# ---------------------------------
# Script header information
# ---------------------------------
echo -e "============================== ${BYellow}Script Info${NC} =============================="
echo -e "${BYellow}Author: ${BLBlue}Nikola Catic @HTEC${NC}"
echo -e "${BYellow}Date: ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description: ${BLBlue}Setup MLPerf ResNet50 Inference benchmark${NC}"
echo "========================================================================="

# ---------------------------------
# Allow installation from insecure repos
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Allowing insecure APT repositories for dependency installation."
echo 'Acquire::AllowInsecureRepositories "true";' > /etc/apt/apt.conf.d/99insecure
echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99insecure


# ---------------------------------
# Extract Information about the System
# ---------------------------------

# Extract Ubuntu version from /etc/lsb-release
if [ -f /etc/lsb-release ]; then
    source /etc/lsb-release
    ubuntu_version="$DISTRIB_RELEASE"
else
    echo -e "${BRed}[ERROR]:${NC}/etc/lsb-release not found. Cannot determine Ubuntu version."
    exit 1
fi

# Get Python version
if command -v python3 &> /dev/null; then
    python_version=$(python3 -V 2>&1 | awk '{print $2}' | cut -d. -f1,2)
else
    echo -e "${BRed}[ERROR]:${NC}python3 not found. Install Python."
    exit 1
fi

# Detected versions
echo -e "${BGreen}[NOTE]Detected Ubuntu version: ${BYellow}$ubuntu_version${NC}"
echo -e "${BGreen}[NOTE]Detected Python version: ${BYellow}$python_version${NC}"

# ---------------------------------
# Install essential system dependencies
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Updating package lists..."
apt update

echo -e "${BLBlue}[NOTE]:${NC} Installing core tools (Python, Git, pip, and venv, vim, sed, wget)..."

sudo apt install -y python3-pip wget git python3 python3-pip vim sed
if [[ "$python_version" == "3.12" ]]; then
    sudo apt -y install python3.12-venv 
else
    sudo apt -y install python3.10-venv 
fi

echo -e "${BLBlue}[NOTE]:${NC} Installing MIGraphX and half precision libs..."
sudo apt install -y migraphx half

# ---------------------------------
# Validate MIGraphX installation
# ---------------------------------
echo -e "${BLBlue}[TEST]:${NC} Testing MIGraphX driver performance..."
/opt/rocm-6.4.1/bin/migraphx-driver perf --test

# ---------------------------------
# Install GUI dependency libgtk2.0-dev
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Installing libgtk2.0-dev to resolve GTK errors..."
apt-get install -y libgtk2.0-dev

# ---------------------------------
# Setup Python virtual environment for MLC
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Creating and activating Python virtual environment..."
cd /root
python3 -m venv .venv
source .venv/bin/activate
echo -e "${BLBlue}[NOTE]:${NC} Upgrading pip and wheel..."
pip3 install --upgrade pip wheel

# Install Additional packages
echo -e "${BLBlue}[NOTE]:${NC} Installing opencv-python, pycocotools, tools into venv..."
pip install opencv-python
pip install pycocotools
pip install tools

# Initialize MLPerf environment
echo -e "${BLBlue}[NOTE]:${NC} Setting up MLPerf environment via mlcr..."
mlcr install,python-venv --name=mlperf
export MLC_SCRIPT_EXTRA_CMD="--adr.python.name=mlperf"

# ---------------------------------
# Install and verify ONNX Runtime for ROCm
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Installing ROCm-enabled ONNX Runtime..."
pip3 uninstall -y onnxruntime-rocm
if [[ "$ubuntu_version" == "24.04" && "$python_version" == "3.12" ]]; then
    pip install https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/onnxruntime_rocm-1.21.0-cp312-cp312-manylinux_2_28_x86_64.whl
elif [[ "$ubuntu_version" == "22.04" && "$python_version" == "3.10" ]]; then
    pip install https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/onnxruntime_rocm-1.21.0-cp310-cp310-manylinux_2_28_x86_64.whl
else
    echo -e "${BRed}[ERROR]:${NC} Invalid combination of Python and Ubuntu."
    exit 1
fi

echo -e "${BLBlue}[TEST]:${NC} Verifying ONNX Runtime providers..."
python3 -c "import onnxruntime as ort; print('Providers:', ort.get_available_providers())"

# ---------------------------------
# Download MLPerf Inference Repo and configure LoadGen 
# ---------------------------------
cd /root
# Clone repo and install loadgen
echo -e "${BLBlue}[NOTE]:${NC} Cloning MLPerf Inference repo to root."
git clone https://github.com/mlcommons/inference.git

echo -e "${BLBlue}[NOTE]:${NC} Installing LoadGen."
cd /root/inference/loadgen
pip install -e .

# ---------------------------------
# Replace Execution Provider in Python backend
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Switching CUDAExecutionProvider to ROCMExecutionProvider in ONNX script..."
sed -i -e 's/CUDAExecutionProvider/ROCMExecutionProvider/g' \
    /root/inference/vision/classification_and_detection/python/backend_onnxruntime.py

# ---------------------------------
# Install mlc-scripts and download model and dataset
# ---------------------------------

# Install mlc-scripts
echo -e "${BLBlue}[NOTE]:${NC} Installing mlc-scripts."
pip install mlc-scripts

echo -e "${BLBlue}[NOTE]:${NC} Creating /dataset/imagenet folder."
mkdir -p /dataset/imagenet

echo -e "${BLBlue}[NOTE]:${NC} Creating /model folder."
mkdir -p /model

echo -e "${BLBlue}[NOTE]:${NC} Downloading dataset and model."
mlcr get,dataset,image-classification,imagenet,preprocessed,_full,_pytorch -j

cd /root/MLC/repos/local/cache/get-dataset-imagenet-val_*/imagenet-2012-val/ 
mv * /dataset/imagenet
wget -P /model https://zenodo.org/record/2592612/files/resnet50_v1.onnx
cd /root/inference/vision/classification_and_detection/
# ---------------------------------
# Completion message
# ---------------------------------
echo -e "================================= ${BYellow}ResNet50 Benchmark Setup Finished${NC} "=================================