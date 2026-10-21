#!/usr/bin/env bash
set -euo pipefail

release=${1:-}
version_file="/repo/versions/ubuntu-$release.env"
[[ -r "$version_file" ]] || {
    echo "Unsupported Ubuntu release: $release" >&2
    exit 2
}
# shellcheck disable=SC1090
source "$version_file"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl devscripts dpkg-dev equivs fakeroot patch

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

curl --fail --location --retry 4 --output "$ORIG_FILE" "$ORIG_URL"
curl --fail --location --retry 4 --output "$DEBIAN_FILE" "$DEBIAN_URL"
curl --fail --location --retry 4 --output "$DSC_FILE" "$DSC_URL"
printf '%s  %s\n' "$ORIG_SHA256" "$ORIG_FILE" | sha256sum --check --strict
printf '%s  %s\n' "$DEBIAN_SHA256" "$DEBIAN_FILE" | sha256sum --check --strict
printf '%s  %s\n' "$DSC_SHA256" "$DSC_FILE" | sha256sum --check --strict

dpkg-source --no-check -x "$DSC_FILE" source
mk-build-deps --install --remove \
    --tool 'apt-get -y --no-install-recommends' source/debian/control

cd source
pskauth_patch=eap_authenticator-fortigate-pskauth.patch
[[ "$release" != 24.04 ]] || pskauth_patch=eap_authenticator-fortigate-pskauth-noble.patch
patches=(
    eap_payload-fortigate.patch
    eap_authenticator-fortigate.patch
    eap_gtc-otp-v3.patch
    "$pskauth_patch"
    ike_auth-fortigate-fct.patch
    ike_vendor-forticlient-vid.patch
)
for patch_name in "${patches[@]}"; do
    echo "Applying $patch_name"
    patch --batch --forward -p1 <"/repo/patches/$patch_name"
done

build_jobs=$(nproc)
export DEB_BUILD_OPTIONS="parallel=$build_jobs"
dpkg-buildpackage -b -us -uc

shopt -s nullglob
packages=(
    ../strongswan-libcharon_"${STRONGSWAN_VERSION}"_*.deb
    ../libcharon-extra-plugins_"${STRONGSWAN_VERSION}"_*.deb
)
(( ${#packages[@]} == 2 )) || {
    echo "The build did not produce exactly the two expected packages." >&2
    printf '%s\n' "${packages[@]}" >&2
    exit 1
}
install -m 644 "${packages[@]}" /out/
cd /out
sha256sum ./*.deb >SHA256SUMS
printf '%s\n' "$STRONGSWAN_VERSION" >STRONGSWAN_VERSION
