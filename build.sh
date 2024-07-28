#!/usr/bin/env bash

./build-llvm.py \
  --assertions \
  --vendor-string "Tea" \
  --targets AArch64 ARM X86 \
  --pgo kernel-defconfig \
  --lto full \
  --shallow-clone \
  --no-update

./build-binutils.py \
  --targets arm aarch64 x86_64
  
