#!/usr/bin/env bash

set -veuo pipefail

# Helper function to perform a Pixeldrain API call
function pixeldrain_call() {
    local file_path="$1"
    resp=$(curl -sf --upload-file "$file_path" "https://pixeldrain.com/api/file")
    
    if [ $? -ne 0 ]; then
        echo "Pixeldrain upload failed."
        exit 1
    fi
    
    file_id=$(echo "$resp" | jq -r .id)
    echo "https://pixeldrain.com/u/$file_id"
}

# Helper function to send a Telegram message
function tg_send() {
    local msg_type="$1"
    shift

    local args=()
    for arg in "$@"; do
        args+=(-F "$arg")
    done

    curl -sf --form-string chat_id="$TG_CHAT_ID" \
        "${args[@]}" \
        "https://api.telegram.org/bot$TG_TOKEN/send$msg_type" \
        > /dev/null
}

# Generate build info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

# Generate release info
builder_commit="$(git rev-parse HEAD)"
pushd llvm-project
llvm_commit="$(git rev-parse HEAD)"
short_llvm_commit="$(cut -c-8 <<< $llvm_commit)"
popd

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$llvm_commit"
binutils_ver="$(ls | grep "^binutils-" | sed "s/binutils-//g")"

# Create tarball
tarball_name="clang+llvm-$rel_date.tar.gz"
tar -czvf "$tarball_name" -C install .

# Upload tarball to Pixeldrain
pixeldrain_url=$(pixeldrain_call "$tarball_name")
echo "Pixeldrain URL: $pixeldrain_url"

# Send Telegram notification
set +u  # we're checking potentially unset variables here
if [[ -n "$TG_CHAT_ID" ]] && [[ -n "$TG_TOKEN" ]]; then
    if [[ -n "$GH_RUN_ID" ]]; then
        build_desc="[$rel_date build](https://github.com/$GH_BUILD_REPO/actions/runs/$GH_RUN_ID)"
    else
        build_desc="*$rel_date build*"
    fi
    set -u

    tg_send Message parse_mode=Markdown disable_web_page_preview=true text="$build_desc on LLVM commit [$short_llvm_commit]($llvm_commit_url) is now available: [tarball]($pixeldrain_url)"
fi
