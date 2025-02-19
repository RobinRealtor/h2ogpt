#!/bin/bash
set -o pipefail
set -ex

export DEBIAN_FRONTEND=noninteractive
export PATH=/h2ogpt_conda/bin:$PATH
export HOME=/workspace
export CUDA_HOME=/usr/local/cuda-11.8

# Install linux dependencies
apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    software-properties-common \
    pandoc \
    vim \
    libmagic-dev \
    poppler-utils \
    tesseract-ocr \
    libtesseract-dev \
    libreoffice \
    autoconf \
    libtool

# Run upgrades
apt-get upgrade -y

# Install conda
wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh && \
    mkdir -p /h2ogpt_conda && \
    bash ./Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -b -u -p /h2ogpt_conda && \
    conda install python=3.10 pygobject weasyprint -c conda-forge -y

export PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu118"

bash docs/linux_install.sh

chmod -R a+rwx /h2ogpt_conda

# setup tiktoken cache
export TIKTOKEN_CACHE_DIR=/workspace/tiktoken_cache
python3.10 -c "
import tiktoken
from tiktoken_ext import openai_public
# FakeTokenizer etc. needs tiktoken for general tasks
for enc in openai_public.ENCODING_CONSTRUCTORS:
    encoding = tiktoken.get_encoding(enc)
model_encodings = [
    'gpt-4',
    'gpt-4-0314',
    'gpt-4-32k',
    'gpt-4-32k-0314',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-16k',
    'gpt-3.5-turbo-0301',
    'text-ada-001',
    'ada',
    'text-babbage-001',
    'babbage',
    'text-curie-001',
    'curie',
    'davinci',
    'text-davinci-003',
    'text-davinci-002',
    'code-davinci-002',
    'code-davinci-001',
    'code-cushman-002',
    'code-cushman-001'
]
for enc in model_encodings:
    encoding = tiktoken.encoding_for_model(enc)
print('Done!')
"

############################################################
# vllm server
export VLLM_CACHE=/workspace/.vllm_cache
cd /h2ogpt_conda
python -m venv vllm_env --system-site-packages
# gputil is for rayWorker in vllm to run as non-root
/h2ogpt_conda/vllm_env/bin/python -m pip install https://github.com/vllm-project/vllm/releases/download/v0.2.2/vllm-0.2.2+cu118-cp310-cp310-manylinux1_x86_64.whl
/h2ogpt_conda/vllm_env/bin/python -m pip install ray pandas gputil==1.4.0
mkdir $VLLM_CACHE
chmod -R a+rwx /h2ogpt_conda

# Make sure old python location works in case using scripts from old documentation
mkdir -p /h2ogpt_conda/envs/vllm/bin
ln -s /h2ogpt_conda/vllm_env/bin/python3.10 /h2ogpt_conda/envs/vllm/bin/python3.10

# Track build info
cd /workspace && make build_info.txt
cp /workspace/build_info.txt /build_info.txt

mkdir -p /workspace/save
chmod -R a+rwx /workspace/save

# Cleanup
rm -rf /workspace/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh
rm -rf /workspace/.cache/pip
