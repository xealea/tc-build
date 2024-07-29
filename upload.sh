#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Helper function to send a Telegram message
tg_send() {
    local msg_type="$1"
    shift

    curl -sf --form-string chat_id="$TG_CHAT_ID" \
        --form "$@" \
        "https://api.telegram.org/bot$TG_TOKEN/send$msg_type" \
        > /dev/null
}

# Generate build info
rel_date=$(date "+%Y%m%d")
rel_friendly_date=$(date "+%B %-d, %Y")
clang_version=$(install/bin/clang --version | awk 'NR==1 {print $4}')

# Generate release info
pushd llvm-project > /dev/null
llvm_commit=$(git rev-parse HEAD)
short_llvm_commit=${llvm_commit:0:8}
popd > /dev/null

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$llvm_commit"
binutils_ver=$(ls | grep "^binutils-" | sed "s/binutils-//")

# Build tarball
tarball_path="../$rel_date.tar.gz"

# Upload tarball to Pixeldrain
tarball_url=$(curl -sf -F "file=@$tarball_path" https://pixeldrain.com/api/file | jq -r '.url')
echo "Tarball uploaded: $tarball_url"

# Send Telegram notification
if [[ -n "${TG_CHAT_ID-}" && -n "${TG_TOKEN-}" ]]; then
    build_desc="[${rel_date} build](https://github.com/llvm/llvm-project/commit/${llvm_commit})"
    tg_send Message parse_mode=Markdown disable_web_page_preview=true text="${build_desc} with LLVM commit [${short_llvm_commit}](${llvm_commit_url}) is now available: [tarball](${tarball_url})"
fi
