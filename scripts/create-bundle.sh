#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
for release in 24.04 26.04; do
    [[ -r "$repo_dir/dist/ubuntu-$release/SHA256SUMS" ]] || {
        echo "Missing Ubuntu $release artifacts. Run make build." >&2
        exit 1
    }
    (cd "$repo_dir/dist/ubuntu-$release" && sha256sum --check --strict SHA256SUMS)
done

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
bundle_root="$stage/fortivpn-sgcan"
mkdir -p "$bundle_root"
for path in AGENTS.md README.md INSTALL.md SECURITY.md NOTICE.md LICENSE Makefile install.sh \
    client config desktop systemd patches strongswan versions scripts tests dist; do
    cp -a "$repo_dir/$path" "$bundle_root/"
done
rm -rf "$bundle_root/client/__pycache__"
mkdir -p "$repo_dir/release"
archive="$repo_dir/release/fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz"
tar --sort=name --mtime='UTC 2020-01-01' --owner=0 --group=0 --numeric-owner \
    -czf "$archive" -C "$stage" fortivpn-sgcan
archive_name=${archive##*/}
(cd "$repo_dir/release" && sha256sum "$archive_name" >"$archive_name.sha256")
echo "Bundle created: $archive"
