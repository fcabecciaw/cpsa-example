#!/bin/bash
#ARCH=/opt/vitis_ai/compiler/arch/DPUCZDX8G/KV260/arch.json
ARCH=./arch_kv260_benchmark_b4096.json
TARGET=kv260
echo "-----------------------------------------"
echo "COMPILING MODEL FOR KV260.."
echo "-----------------------------------------"

CNN_MODEL=$1

compile() {
  vai_c_xir \
	--xmodel           ./build/quantized/${CNN_MODEL} \
	--arch            ${ARCH} \
	--output_dir      ./build/compiled_${TARGET} \
	--net_name        ${TARGET}_${CNN_MODEL}
#	--options         "{'mode':'debug'}"
#  --options         '{"input_shape": "1,224,224,3"}' \
}


compile #2>&1 | tee build/log/compile_$TARGET.log


echo "-----------------------------------------"
echo "MODEL COMPILED"
echo "-----------------------------------------"
