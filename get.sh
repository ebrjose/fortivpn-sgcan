#!/usr/bin/env bash
# Download, verify, and install the latest fortivpn-sgcan release bundle.
#
#   curl -fsSL https://raw.githubusercontent.com/ebrjose/fortivpn-sgcan/main/get.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/ebrjose/fortivpn-sgcan/main/get.sh | bash -s -- --headless
#
# Options: --desktop (default) | --headless, and --version TAG (default: latest).
set -euo pipefail

repo=ebrjose/fortivpn-sgcan
bundle=fortivpn-sgcan-ubuntu-24.04-26.04-amd64.tar.gz
install_root=${XDG_DATA_HOME:-$HOME/.local/share}/fortivpn-sgcan
tmp=''

die() {
    echo "ERROR: $*" >&2
    exit 1
}

download() {
    if command -v curl >/dev/null; then
        curl -fsSL --retry 3 -o "$2" "$1"
    else
        wget -q -O "$2" "$1"
    fi
}

main() {
    local mode=--desktop version=latest
    while (($#)); do
        case "$1" in
            --desktop|--headless) mode=$1 ;;
            --version)
                [[ -n "${2:-}" ]] || die '--version requires a tag, for example v1.0.0.'
                version=$2
                shift
                ;;
            *) die "Usage: get.sh [--desktop|--headless] [--version TAG]" ;;
        esac
        shift
    done

    (( EUID != 0 )) || die 'Run as a regular user; the installer requests privileges when needed.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" =~ ^(24|26)\.04$ ]] ||
        die "Unsupported system: ${PRETTY_NAME:-unknown}. Use Ubuntu 24.04 or 26.04."
    [[ $(dpkg --print-architecture) == amd64 ]] || die 'Only amd64 is supported.'
    command -v curl >/dev/null || command -v wget >/dev/null || die 'Install curl or wget first.'
    if [[ "$mode" == --desktop ]]; then
        command -v pkexec >/dev/null || die 'Desktop mode requires pkexec: sudo apt install pkexec'
    fi

    local base
    if [[ "$version" == latest ]]; then
        base="https://github.com/$repo/releases/latest/download"
    else
        [[ "$version" =~ ^v[0-9A-Za-z.+-]+$ ]] || die "Invalid version tag: $version"
        base="https://github.com/$repo/releases/download/$version"
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    echo "Downloading $bundle ($version)..."
    download "$base/$bundle" "$tmp/$bundle" || die "Could not download $base/$bundle"
    download "$base/$bundle.sha256" "$tmp/$bundle.sha256" || die 'Could not download the checksum.'
    (cd "$tmp" && sha256sum --check --strict "$bundle.sha256") || die 'SHA-256 verification failed.'

    # Keep the extracted bundle: scripts/rollback.sh is needed later to restore
    # the official strongSwan packages.
    rm -rf "$install_root"
    mkdir -p "$install_root"
    tar -xzf "$tmp/$bundle" -C "$install_root" --strip-components=1

    echo "Bundle extracted to $install_root"
    "$install_root/install.sh" "$mode"
    echo "To restore the official strongSwan packages later: sudo $install_root/scripts/rollback.sh"
}

main "$@"
