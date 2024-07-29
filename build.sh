#!/usr/bin/env bash

# Function to display messages
msg() {
    echo "$1"
}

# Build LLVM and Binutils
msg "Building LLVM and Binutils..."
./build-llvm.py \
  --vendor-string "Tea" \
  --targets AArch64 ARM X86 \
  --pgo kernel-defconfig \
  --lto full \
  --shallow-clone

./build-binutils.py \
  --targets arm aarch64 x86_64

# Remove unused products
msg "Removing unused products..."
rm -rf install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "Stripping remaining products..."
find install -type f -exec file {} + | \
grep 'not stripped' | \
cut -d: -f1 | \
xargs -r strip

# Set executable rpaths
msg "Setting library load paths for portability..."
find install -mindepth 2 -maxdepth 3 -type f -exec file {} + | \
grep 'ELF .* interpreter' | \
cut -d: -f1 | \
xargs -r -I{} patchelf --set-rpath '$ORIGIN/../lib' {}
