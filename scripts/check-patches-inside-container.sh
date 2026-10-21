#!/usr/bin/env bash
set -euo pipefail

release=$1
# shellcheck disable=SC1090
source "/repo/versions/ubuntu-$release.env"
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl dpkg-dev patch xz-utils bzip2
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
cd source
pskauth_patch=eap_authenticator-fortigate-pskauth.patch
[[ "$release" != 24.04 ]] || pskauth_patch=eap_authenticator-fortigate-pskauth-noble.patch
for patch_name in \
    eap_payload-fortigate.patch \
    eap_authenticator-fortigate.patch \
    eap_gtc-otp-v3.patch \
    "$pskauth_patch" \
    ike_auth-fortigate-fct.patch \
    ike_vendor-forticlient-vid.patch; do
    patch --batch --forward -p1 <"/repo/patches/$patch_name"
done
echo "All six patches apply cleanly to Ubuntu $release ($STRONGSWAN_VERSION)."
