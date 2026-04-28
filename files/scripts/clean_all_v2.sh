#!/bin/bash

# Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
# SPDX-License-Identifier: MIT

# standard:
#   - fully remove and recreate ./build
#   - remove generated target-side runtime artifacts under ./target/vcor
# factory:
#   - same as standard
#   - also remove extracted auxiliary assets that are not part of a clean shipped tree
#   - if REMOVE_USER_DOWNLOADS=1, also delete downloaded archives in ./files

set -euo pipefail

CLEAN_MODE="${1:-standard}"
REMOVE_USER_DOWNLOADS="${REMOVE_USER_DOWNLOADS:-0}"

case "$CLEAN_MODE" in
  standard|factory) ;;
  *)
    echo "ERROR: unsupported clean mode '$CLEAN_MODE'"
    echo "Valid values: standard, factory"
    exit 1
    ;;
esac

case "$REMOVE_USER_DOWNLOADS" in
  0|1) ;;
  *)
    echo "ERROR: REMOVE_USER_DOWNLOADS must be 0 or 1"
    exit 1
    ;;
esac

echo " "
echo "----------------------------------------------------------------------------------"
echo "[DB INFO STEP0] CLEANING BUILD TREE (${CLEAN_MODE})"
echo "----------------------------------------------------------------------------------"

while IFS= read -r -d '' file; do rm -f "$file"; done < <(find . -name "*.fuse_hidden*" -print0)
while IFS= read -r -d '' file; do rm -f "$file"; done < <(find . -name "*.*~" -print0)

rm -rf ./build
mkdir -p ./build ./build/log ./build/float ./build/quantized ./build/compiled_kv260 ./build/data

if [ -d ./target/vcor ]; then
  rm -f ./target/vcor/*.xmodel
  rm -f ./target/vcor/*.txt
  rm -f ./target/vcor/*.log
  rm -f ./target/vcor/*~
  rm -f ./target/vcor/cnn_resnet18_vcor
  rm -f ./target/vcor/get_dpu_fps
  rm -f ./target/vcor/run_cnn
  rm -f ./target/vcor/test.tar
  rm -rf ./target/vcor/rpt
  rm -rf ./target/vcor/test
  mkdir -p ./target/vcor/rpt
fi

if [ "$CLEAN_MODE" = "factory" ]; then
  echo "Factory cleanup requested: removing extracted auxiliary assets"
  rm -rf ./pt_vehicle-color-classification_3.5

  if [ "$REMOVE_USER_DOWNLOADS" = "1" ]; then
    echo "REMOVE_USER_DOWNLOADS=1 -> deleting downloaded archives from the tutorial folder"
    rm -f ./archive.zip
    rm -f ./pt_vehicle-color-classification_3.5.zip
  fi
fi

echo "Build directory recreated under ./build"
echo "Cleanup completed"
