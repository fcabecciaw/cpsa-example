#!/bin/bash

# Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

set -euo pipefail

echo "Conducting Quantization"

DATA_DIR=./build/data
WEIGHTS_FILE=${MODEL_FILE:-./build/float/color_last_resnet18.pt}
DATASET=${DATASET_NAME:-vcor}
GPU_ID=${GPU_ID:-0}
BACKBONE=${BACKBONE:-resnet18}
TEST_BATCH_SIZE=${TEST_BATCH_SIZE:-1}
QUANT_DIR=${QUANT_DIR:-./build/quantized}
export PYTHONPATH=${PWD}:${PYTHONPATH:-}

if [ ! -f "$WEIGHTS_FILE" ]; then
  echo "ERROR: floating-point checkpoint not found: $WEIGHTS_FILE"
  exit 1
fi

if [ ! -d "${DATA_DIR}/${DATASET}" ]; then
  echo "ERROR: dataset directory not found: ${DATA_DIR}/${DATASET}"
  exit 1
fi

mkdir -p "$QUANT_DIR"

CUDA_VISIBLE_DEVICES=${GPU_ID} python code/test.py --backbone "$BACKBONE" --resume "$WEIGHTS_FILE" --data_root "${DATA_DIR}/${DATASET}" --quant_mode calib --quant_dir "$QUANT_DIR" --test-batch-size "$TEST_BATCH_SIZE"
CUDA_VISIBLE_DEVICES=${GPU_ID} python code/test.py --backbone "$BACKBONE" --resume "$WEIGHTS_FILE" --data_root "${DATA_DIR}/${DATASET}" --quant_mode test  --quant_dir "$QUANT_DIR" --test-batch-size "$TEST_BATCH_SIZE"
CUDA_VISIBLE_DEVICES=${GPU_ID} python code/test.py --backbone "$BACKBONE" --resume "$WEIGHTS_FILE" --data_root "${DATA_DIR}/${DATASET}" --quant_mode test  --quant_dir "$QUANT_DIR" --deploy --device cpu --test-batch-size "$TEST_BATCH_SIZE"
