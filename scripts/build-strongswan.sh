#!/usr/bin/env bash
set -euo pipefail

release=${1:-}
case "$release" in
    24.04|26.04) ;;
    *) echo "Usage: $0 24.04|26.04" >&2; exit 2 ;;
esac

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
out_dir="$repo_dir/dist/ubuntu-$release"
mkdir -p "$out_dir"

docker run --rm \
    --volume "$repo_dir:/repo:ro" \
    --volume "$out_dir:/out" \
    --env DEBIAN_FRONTEND=noninteractive \
    "ubuntu:$release" \
    /repo/scripts/build-inside-container.sh "$release"

echo "Artifacts generated in $out_dir"
