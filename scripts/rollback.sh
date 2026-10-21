#!/usr/bin/env bash
set -euo pipefail

(( EUID == 0 )) || {
    echo "Usage: sudo $0" >&2
    exit 1
}
[[ -r /var/lib/fortivpn/install.env ]] || {
    echo 'No FortiVPN SGCAN installation information was found.' >&2
    exit 1
}
# shellcheck disable=SC1091
source /var/lib/fortivpn/install.env
backup_dir="/var/backups/fortivpn-sgcan/$UBUNTU_VERSION-$STRONGSWAN_VERSION"
shopt -s nullglob
official=("$backup_dir"/official/*.deb)
(( ${#official[@]} == 2 )) || {
    echo "The two official packages were not found in $backup_dir/official" >&2
    exit 1
}
/usr/local/sbin/fortivpn-down 2>/dev/null || true
apt-mark unhold strongswan-libcharon libcharon-extra-plugins || true
dpkg -i "${official[@]}"
systemctl restart strongswan
echo 'The official packages were restored. Profiles were preserved.'
