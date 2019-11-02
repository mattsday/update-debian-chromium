#!/bin/sh
# Download Debian security update package list
PACKAGES="$(curl -s 'http://security-cdn.debian.org/debian-security/dists/buster/updates/main/binary-amd64/Packages.xz' | unxz -c)"

# Find version for chromium and chromium-common
CHROMIUM="$(echo "$PACKAGES" | sed -n '/Package: chromium$/,/^$/p')"
CHROMIUM_VERSION="$(echo "$CHROMIUM" | grep 'Version:' | awk -F: '{print $2}' | xargs)"

CHROMIUM_COMMON="$(echo "$PACKAGES" | sed -n '/Package: chromium-common$/,/^$/p')"
CHROMIUM_COMMON_VERSION="$(echo "$CHROMIUM_COMMON" | grep 'Version:' | awk -F: '{print $2}' | xargs)"

echo "$CHROMIUM_VERSION"
echo "$CHROMIUM_COMMON_VERSION"
