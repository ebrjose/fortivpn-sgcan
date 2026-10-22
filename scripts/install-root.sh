#!/usr/bin/env bash
set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

(( EUID == 0 )) || die 'This installer requires root privileges.'
[[ "${1:-}" == --user-uid && "${2:-}" =~ ^[0-9]+$ ]] || die 'The VPN administrator user was not specified.'
target_uid=$2
mode=${3:-}
[[ "$mode" == --desktop || "$mode" == --headless ]] || die 'Invalid installation mode.'
(( target_uid >= 1000 )) || die 'The specified UID does not belong to a regular user.'
target_user=$(getent passwd "$target_uid" | cut -d: -f1)
[[ -n "$target_user" ]] || die 'The specified user does not exist.'
target_group=$(id -gn "$target_user")

repo_dir=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
# shellcheck disable=SC1091
source /etc/os-release
release=${VERSION_ID:-}
case "$release" in
    24.04|26.04) ;;
    *) die "Ubuntu $release is not supported; use 24.04 or 26.04." ;;
esac
[[ $(dpkg --print-architecture) == amd64 ]] || die 'Only amd64 packages are currently built.'

version_file="$repo_dir/versions/ubuntu-$release.env"
[[ -r "$version_file" ]] || die "Missing $version_file"
# shellcheck disable=SC1090
source "$version_file"
dist_dir="$repo_dir/dist/ubuntu-$release"
[[ -r "$dist_dir/SHA256SUMS" ]] ||
    die "Ubuntu $release packages are missing. Run: ./scripts/build-strongswan.sh $release"
(cd "$dist_dir" && sha256sum --check --strict SHA256SUMS) || die 'Package SHA-256 verification failed.'

shopt -s nullglob
libcharon_debs=("$dist_dir"/strongswan-libcharon_"$STRONGSWAN_VERSION"_amd64.deb)
extra_debs=("$dist_dir"/libcharon-extra-plugins_"$STRONGSWAN_VERSION"_amd64.deb)
(( ${#libcharon_debs[@]} == 1 && ${#extra_debs[@]} == 1 )) || die 'Exactly two expected packages were not found.'
[[ $(dpkg-deb -f "${libcharon_debs[0]}" Version) == "$STRONGSWAN_VERSION" ]] || die 'Incorrect strongswan-libcharon version.'
[[ $(dpkg-deb -f "${extra_debs[0]}" Version) == "$STRONGSWAN_VERSION" ]] || die 'Incorrect libcharon-extra-plugins version.'
[[ $(dpkg-deb -f "${libcharon_debs[0]}" Package) == strongswan-libcharon ]] || die 'Incorrect strongswan-libcharon package name.'
[[ $(dpkg-deb -f "${extra_debs[0]}" Package) == libcharon-extra-plugins ]] || die 'Incorrect libcharon-extra-plugins package name.'
[[ $(dpkg-deb -f "${libcharon_debs[0]}" Architecture) == amd64 ]] || die 'Incorrect strongswan-libcharon architecture.'
[[ $(dpkg-deb -f "${extra_debs[0]}" Architecture) == amd64 ]] || die 'Incorrect libcharon-extra-plugins architecture.'

export DEBIAN_FRONTEND=noninteractive
apt-get update
dependencies=(charon-systemd strongswan-swanctl libcharon-extra-plugins libstrongswan-extra-plugins python3)
if [[ "$mode" == --desktop ]]; then
    dependencies+=(zenity)
fi
apt-get install -y "${dependencies[@]}"
installed_version=$(dpkg-query -W -f='${Version}' strongswan-libcharon 2>/dev/null || true)
[[ "$installed_version" == "$STRONGSWAN_VERSION" ]] ||
    die "The repository installed strongSwan $installed_version, but this checkout is pinned to $STRONGSWAN_VERSION. Update versions/ and rebuild."

backup_dir="/var/backups/fortivpn-sgcan/$release-$STRONGSWAN_VERSION"
install -d -o root -g root -m 700 "$backup_dir/official"
if ! compgen -G "$backup_dir/official/*.deb" >/dev/null; then
    (cd "$backup_dir/official" && apt-get download \
        "strongswan-libcharon=$STRONGSWAN_VERSION" \
        "libcharon-extra-plugins=$STRONGSWAN_VERSION")
    chmod 600 "$backup_dir"/official/*.deb
fi
if [[ ! -e "$backup_dir/etc-before.tar.gz" ]]; then
    backup_paths=()
    for path in /etc/fortivpn /etc/swanctl/conf.d/fortivpn-active.conf \
        /etc/strongswan.d/fortigate.conf /etc/strongswan.d/eap-gtc-otp.conf \
        /etc/strongswan.d/charon/fortigate.conf /etc/strongswan.d/charon/eap-gtc-otp.conf \
        /etc/tmpfiles.d/fortivpn.conf; do
        [[ ! -e "$path" ]] || backup_paths+=("$path")
    done
    if (( ${#backup_paths[@]} )); then
        tar -czf "$backup_dir/etc-before.tar.gz" "${backup_paths[@]}"
        chmod 600 "$backup_dir/etc-before.tar.gz"
    fi
fi

systemctl stop strongswan 2>/dev/null || true
dpkg -i "${libcharon_debs[0]}" "${extra_debs[0]}"
apt-mark hold strongswan-libcharon libcharon-extra-plugins

install -o root -g root -m 755 "$repo_dir/client/fortivpn-profile" /usr/local/sbin/fortivpn-profile
install -o root -g root -m 755 "$repo_dir/client/fortivpn-up" /usr/local/sbin/fortivpn-up
install -o root -g root -m 755 "$repo_dir/client/fortivpn-down" /usr/local/sbin/fortivpn-down
install -o root -g root -m 755 "$repo_dir/client/fortivpn-status" /usr/local/sbin/fortivpn-status
install -o root -g root -m 755 "$repo_dir/client/fortigate-otp-helper" /usr/local/sbin/fortigate-otp-helper
install -o root -g root -m 755 "$repo_dir/client/fortivpn-cli" /usr/local/bin/fortivpn-cli
# Both files open a top-level "charon {" section, so they must live directly in
# /etc/strongswan.d: strongswan.conf includes strongswan.d/charon/*.conf inside
# charon.plugins, where these settings would be silently ignored.
install -o root -g root -m 644 "$repo_dir/config/eap-gtc-otp.conf" /etc/strongswan.d/eap-gtc-otp.conf
install -o root -g root -m 644 "$repo_dir/config/fortigate.conf" /etc/strongswan.d/fortigate.conf
rm -f /etc/strongswan.d/charon/eap-gtc-otp.conf /etc/strongswan.d/charon/fortigate.conf

if [[ "$mode" == --desktop ]]; then
    install -o root -g root -m 755 "$repo_dir/client/fortivpn-manager" /usr/local/bin/fortivpn-manager
    install -d -o root -g root -m 755 /usr/local/libexec
    install -o root -g root -m 755 "$repo_dir/client/fortivpn-otp-agent.py" /usr/local/libexec/fortivpn-otp-agent.py
    install -o root -g root -m 644 "$repo_dir/desktop/fortivpn-manager.desktop" /usr/share/applications/fortivpn-manager.desktop
    install -o root -g root -m 644 "$repo_dir/systemd/fortivpn-otp-agent.service" /etc/systemd/user/fortivpn-otp-agent.service
fi

tmpfiles_tmp=$(mktemp)
trap 'rm -f "$tmpfiles_tmp"' EXIT
sed "s/@VPN_GROUP@/$target_group/g" "$repo_dir/config/fortivpn.tmpfiles.in" >"$tmpfiles_tmp"
install -o root -g root -m 644 "$tmpfiles_tmp" /etc/tmpfiles.d/fortivpn.conf
rm -f "$tmpfiles_tmp"
trap - EXIT
systemd-tmpfiles --create /etc/tmpfiles.d/fortivpn.conf

install -d -o root -g root -m 700 /etc/fortivpn/profiles
install -d -o root -g root -m 755 /var/lib/fortivpn
touch /var/lib/fortivpn/profiles.index
chown root:root /var/lib/fortivpn/profiles.index
chmod 644 /var/lib/fortivpn/profiles.index
/usr/local/sbin/fortivpn-profile import-legacy
/usr/local/sbin/fortivpn-profile refresh-index

{
    printf 'UBUNTU_VERSION=%s\n' "$release"
    printf 'STRONGSWAN_VERSION=%s\n' "$STRONGSWAN_VERSION"
    printf 'MODE=%s\n' "${mode#--}"
    printf 'TARGET_USER=%s\n' "$target_user"
} >/var/lib/fortivpn/install.env
chown root:root /var/lib/fortivpn/install.env
chmod 644 /var/lib/fortivpn/install.env

systemctl daemon-reload
systemctl restart strongswan
echo "fortivpn-sgcan installed for $target_user on Ubuntu $release (${mode#--})."
echo "Rollback available at: $backup_dir"
