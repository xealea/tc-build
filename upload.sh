#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Helper function to perform a GitHub API call
gh_call() {
    local req="$1"
    local server="$2"
    local endpoint="$3"
    shift 3

    local resp
    resp=$(curl -Lfu "$GH_USER:$GH_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -X "$req" \
        "https://$server.github.com/repos/$GH_REL_REPO/$endpoint" \
        "$@" || { echo "Request failed with exit code $?:"; cat; return $?; })

    echo "$resp"
}

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
builder_commit=$(git rev-parse HEAD)
pushd llvm-project > /dev/null
llvm_commit=$(git rev-parse HEAD)
short_llvm_commit=${llvm_commit:0:8}
popd > /dev/null

llvm_commit_url="https://github.com/llvm/llvm-project/commit/$llvm_commit"
binutils_ver=$(ls | grep "^binutils-" | sed "s/binutils-//")

# Update Git repository
git clone "https://$GH_USER:$GH_TOKEN@github.com/$GH_REL_REPO" rel_repo
pushd rel_repo > /dev/null
rm -rf *
cp -r ../install/* .
git checkout README.md LICENSE
git add .
git commit -m "Update to $rel_date build

LLVM commit: $llvm_commit_url
binutils version: $binutils_ver
Builder commit: https://github.com/$GH_BUILD_REPO/commit/$builder_commit"
git push
popd > /dev/null

# Delete the existing release with this date, if necessary
resp=$(gh_call GET api "releases/tags/$rel_date" -sS)
old_rel_id=$(jq -r .id <<< "$resp" || true)
if [[ -n "$old_rel_id" ]]; then
    gh_call DELETE api "releases/$old_rel_id" -sS
fi

# Create new release
payload=$(cat <<END
{
    "tag_name": "$rel_date",
    "target_commitish": "master",
    "name": "$rel_friendly_date",
    "body": "Automated build of LLVM + Clang $clang_version as of commit [$short_llvm_commit]($llvm_commit_url) and binutils $binutils_ver."
}
END
)
resp=$(gh_call POST api "releases" --data-binary "@-" -sS <<< "$payload")
rel_url=$(jq -r .html_url <<< "$resp")
rel_id=$(jq -r .id <<< "$resp")
echo "Release created: $rel_url"
echo "Release ID: $rel_id"

# Send Telegram notification
if [[ -n "${TG_CHAT_ID-}" && -n "${TG_TOKEN-}" ]]; then
    build_desc="[${rel_date} build](https://github.com/$GH_BUILD_REPO/actions/runs/${GH_RUN_ID:-})"
    tg_send Message parse_mode=Markdown disable_web_page_preview=true text="${build_desc} on LLVM commit [${short_llvm_commit}](${llvm_commit_url}) is now available: [tarball](https://github.com/$GH_REL_REPO/archive/$rel_date.tar.gz) or [Git repository](https://github.com/$GH_REL_REPO)"
fi
