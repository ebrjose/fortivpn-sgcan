#!/usr/bin/env bash
set -euo pipefail

release=${1:-}
case "$release" in
    24.04|26.04) ;;
    *) echo "Usage: $0 24.04|26.04" >&2; exit 2 ;;
esac

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
docker run --rm \
    --volume "$repo_dir:/repo:ro" \
    --env DEBIAN_FRONTEND=noninteractive \
    "ubuntu:$release" \
    /repo/scripts/check-patches-inside-container.sh "$release"
