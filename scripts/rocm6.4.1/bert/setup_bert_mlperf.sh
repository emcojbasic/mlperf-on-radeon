#!/bin/bash

# =============================================================================
# This script installs dependencies and configures the environment
# for BERT benchmarking with MLPerf.
#
# Usage: ./run_benchmark.sh
# =============================================================================

# Color definitions
BLBlue='\033[1;34m'    # Bold Light Blue
BYellow='\033[1;33m'    # Bold Yellow
BRed='\033[1;31m'    # Bold Red
BGreen='\033[1;32m'       # Bold Green
NC='\033[0m'            # No Color (reset)

# ---------------------------------
# Script header information
# ---------------------------------
echo -e "============================== ${BYellow}Script Info${NC} =============================="
echo -e "${BYellow}Author: ${BLBlue}Nikola Catic, Emilija Cojbasic @HTEC${NC}"
echo -e "${BYellow}Date: ${BLBlue}$(date +"%Y-%m-%d")${NC}"
echo -e "${BYellow}Description: ${BLBlue}Setup MLPerf BERT MLPerf Inference benchmark${NC}"
echo "=========================================================================="

# ---------------------------------
# Allow installation from insecure repos (if needed)
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Temporarily allowing insecure APT repositories for dependency install."
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
# Install system dependencies
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Updating package lists..."
sudo apt update

echo -e "${BLBlue}[NOTE]:${NC} Installing core tools (python3-pip, wget, git, python3, vim)..."

if [[ "$python_version" == "3.12" ]]; then
    sudo apt -y install python3.12-venv 
else
    sudo apt -y install python3.10-venv 
fi

sudo apt install -y python3-pip wget git python3 python3-pip vim sed

echo -e "${BLBlue}[NOTE]:${NC} Installing GUI dependency libgtk2.0-dev..."
apt-get install -y libgtk2.0-dev

# ---------------------------------
# Setup Python virtual environment
# ---------------------------------
echo -e "${BLBlue}[NOTE]:${NC} Creating and activating Python virtual environment..."
cd /root
python3 -m venv .venv
source .venv/bin/activate
echo -e "${BLBlue}[NOTE]:${NC} Upgrading pip and wheel..."
pip3 install --upgrade pip wheel

# Install MLC scripts
echo -e "${BLBlue}[NOTE]:${NC} Installing MLC scripts into venv..."
pip install mlc-scripts

# Install Additional packages
echo -e "${BLBlue}[NOTE]:${NC} Installing absl-py, tokenization, transformers into venv..."
pip install absl-py
pip install tokenization
pip install transformers

# ---------------------------------
# Install PyTorch wheels for ROCm
# ---------------------------------

echo -e "${BLBlue}[NOTE]:${NC} Downloading and installing ROCm-enabled PyTorch, TorchVision, TorchAudio, and Triton..."
# Check for allowed combinations
if [[ "$ubuntu_version" == "24.04" && "$python_version" == "3.12" ]]; then
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torchvision-0.22.1%2Brocm6.4.1.git59a3e1f9-cp312-cp312-linux_x86_64.whl 
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torchaudio-2.7.1%2Brocm6.4.1.git95c61b41-cp312-cp312-linux_x86_64.whl
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torch-2.7.1%2Brocm6.4.1.git2a215e4a-cp312-cp312-linux_x86_64.whl
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/pytorch_triton_rocm-3.3.1%2Brocm6.4.1.git40e90a0a-cp312-cp312-linux_x86_64.whl

    pip3 uninstall -y torch torchvision pytorch-triton-rocm

    pip install \
        torch-2.7.1+rocm6.4.1.git2a215e4a-cp312-cp312-linux_x86_64.whl \
        torchaudio-2.7.1+rocm6.4.1.git95c61b41-cp312-cp312-linux_x86_64.whl \
        torchvision-0.22.1+rocm6.4.1.git59a3e1f9-cp312-cp312-linux_x86_64.whl \
        pytorch_triton_rocm-3.3.1+rocm6.4.1.git40e90a0a-cp312-cp312-linux_x86_64.whl
elif [[ "$ubuntu_version" == "22.04" && "$python_version" == "3.10" ]]; then
    echo -e "${BLBlue}[NOTE]:${NC} Downloading and installing ROCm-enabled PyTorch, TorchVision, TorchAudio, and Triton..."
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torch-2.6.0%2Brocm6.4.1.git1ded221d-cp310-cp310-linux_x86_64.whl
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torchvision-0.21.0%2Brocm6.4.1.git4040d51f-cp310-cp310-linux_x86_64.whl
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/pytorch_triton_rocm-3.2.0%2Brocm6.4.1.git6da9e660-cp310-cp310-linux_x86_64.whl
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/torchaudio-2.6.0%2Brocm6.4.1.gitd8831425-cp310-cp310-linux_x86_64.whl

    pip3 uninstall -y torch torchvision pytorch-triton-rocm
    pip3 install \
        torch-2.6.0+rocm6.4.1.git1ded221d-cp310-cp310-linux_x86_64.whl \
        torchvision-0.21.0+rocm6.4.1.git4040d51f-cp310-cp310-linux_x86_64.whl \
        torchaudio-2.6.0+rocm6.4.1.gitd8831425-cp310-cp310-linux_x86_64.whl \
        pytorch_triton_rocm-3.2.0+rocm6.4.1.git6da9e660-cp310-cp310-linux_x86_64.whl
else
    echo -e "${BRed}[ERROR]:${NC} Invalid combination of Python and Ubuntu."
    exit 1
fi

# ---------------------------------
# Validate PyTorch installation
# ---------------------------------
echo -e "${BLBlue}[TEST]:${NC} Verifying PyTorch import..."
python3 -c 'import torch' 2> /dev/null && echo -e "${BGreen}[PASS]:${NC} torch imported successfully." || echo -e "${BRed}[FAIL]:${NC} torch import failed."

echo -e "${BLBlue}[TEST]:${NC} Checking CUDA/ROCm availability and device name..."
python3 - << 'EOF'
import torch
available = torch.cuda.is_available()
print(f"CUDA/ROCm available: {available}")
if available:
    print(f"Device name [0]: {torch.cuda.get_device_name(0)}")
EOF

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
# Install mlc-scripts and download model and dataset
# ---------------------------------

# Install mlc-scripts
echo -e "${BLBlue}[NOTE]:${NC} Installing mlc-scripts."
pip install mlc-scripts

# Download the dataset and model:
echo -e "${BLBlue}[NOTE]:${NC} Creating /data/validation folder."
mkdir -p /data/validation

echo -e "${BLBlue}[NOTE]:${NC} Downloading dataset and model."
printf '\n' | mlcr get,ml-model,bert-large,_pytorch --outdirname=/model --non-interactive --yes -j 
printf '\n' | mlcr get,dataset,squad,validation  --outdirname=/data/validation --non-interactive --yes -j
# If you need calibration uncomment this line:
# mlcr get,dataset,squad,_calib1 --outdirname=/data/calibration -j 

#cp /root/MLC/repos/local/cache/download-file_bert-get-datase_*/* /data/v
#alidation/

#echo -e "${BLBlue}[NOTE]:${NC} Downloading missing ${BYellow}vocab.txt${NC}."
#wget https://huggingface.co/google-bert/bert-base-cased/blob/main/vocab.txt -P /data/validation
# maybe even just copy from model

#  pip install transformers==4.46.2 nltk==3.8.1 evaluate==0.4.0      

# ---------------------------------
# Install tensorflow and download tokenization file
# ---------------------------------
cd /root
if [[ "$ubuntu_version" == "24.04" && "$python_version" == "3.12" ]]; then
    echo -e "${BLBlue}[NOTE]:${NC} Downloading and installing Tensorflow"
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/tensorflow_rocm-2.18.1-cp312-cp312-manylinux_2_28_x86_64.whl
    pip install tensorflow_rocm-2.18.1-cp312-cp312-manylinux_2_28_x86_64.whl
elif [[ "$ubuntu_version" == "22.04" && "$python_version" == "3.10" ]]; then
    echo -e "${BLBlue}[NOTE]:${NC} Downloading and installing Tensorflow"
    wget https://repo.radeon.com/rocm/manylinux/rocm-rel-6.4.1/tensorflow_rocm-2.18.1-cp310-cp310-manylinux_2_28_x86_64.whl
    pip install tensorflow_rocm-2.18.1-cp310-cp310-manylinux_2_28_x86_64.whl
else
    echo -e "${BRed}[ERROR]:${NC} Invalid combination of Python and Ubuntu."
    exit 1
fi

echo -e "${BLBlue}[NOTE]:${NC} Downloading tokenization.py file."
cd /root/inference/language/bert
wget https://raw.githubusercontent.com/google-research/bert/master/tokenization.py 

echo -e "${BLBlue}[NOTE]:${NC} Add from tokenization import BasicTokenizer into ${BYellow}accuracy-squad.py${NC}."
sed -i '/from transformers import BertTokenizer/a from tokenization import BasicTokenizer' "accuracy-squad.py"

# ---------------------------------
# Completion message
# ---------------------------------
echo -e "================================= ${BYellow}BERT Benchmark Setup Finished${NC} ================================="