#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$repo_dir"

while IFS= read -r script; do
    bash -n "$script"
done < <(find client scripts -type f -exec sh -c \
    'for f do head -n1 "$f" | grep -q "bash" && printf "%s\n" "$f"; done' sh {} + | sort)

python3 -m py_compile client/fortivpn-otp-agent.py
rm -rf client/__pycache__

if command -v shellcheck >/dev/null; then
    mapfile -t shell_files < <(find client scripts tests -type f -exec sh -c \
        'for f do head -n1 "$f" | grep -q "bash" && printf "%s\n" "$f"; done' sh {} + | sort)
    shellcheck "${shell_files[@]}"
fi

if command -v desktop-file-validate >/dev/null; then
    desktop-file-validate desktop/fortivpn-manager.desktop
fi

[[ $(find patches -maxdepth 1 -name '*.patch' | wc -l) -eq 7 ]]
for release in 24.04 26.04; do
    # shellcheck disable=SC1090
    source "versions/ubuntu-$release.env"
    [[ "$UBUNTU_VERSION" == "$release" ]]
    [[ "$ORIG_SHA256$DEBIAN_SHA256$DSC_SHA256" =~ ^[a-f0-9]{192}$ ]]
done

test_index=$(mktemp)
trap 'rm -f "$test_index"' EXIT
printf 'test\tTest VPN\tLOCAL-ID\tvpn.example.test\t198.51.100.0/24,203.0.113.0/24\n' >"$test_index"
output=$(FORTIVPN_INDEX_FILE="$test_index" client/fortivpn-cli list)
grep -q 'Test VPN' <<<"$output"
grep -q 'LOCAL-ID' <<<"$output"

if find . -path './.git' -prune -o -type f \( -name '*.profile' -o -name 'fct_data.txt' -o -name 'fortivpn-active.conf' \) -print | grep -q .; then
    echo 'Profiles or credential files that must not be committed were found.' >&2
    exit 1
fi

echo 'Local checks completed.'
