#!/bin/bash

# Exit on error
set -e

# Export environment variables
export TG_CHAT_ID="your-value"
export TG_TOKEN="your-value"

# Update and install dependencies
echo "Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y \
  jq \
  curl \
  bc \
  binutils \
  bison \
  build-essential \
  ca-certificates \
  ccache \
  clang \
  cmake \
  file \
  flex \
  git \
  libelf-dev \
  libssl-dev \
  libstdc++-$(apt list libstdc++6 2>/dev/null | grep -Eos '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d . -f 1)-dev \
  lld \
  make \
  ninja-build \
  python3-dev \
  texinfo \
  u-boot-tools \
  xz-utils \
  zlib1g-dev

# Ensure the build and upload scripts are executable
echo "Setting execute permissions on build and upload scripts..."
chmod +x build.sh upload.sh

# Execute the build and upload scripts
echo "Running build script..."
./build.sh

echo "Running upload script..."
./upload.sh

echo "Workflow completed successfully."
