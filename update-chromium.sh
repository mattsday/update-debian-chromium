#!/bin/sh

fail() {
    >&2 echo "$@"
    exit 1
}

warn() {
    >&2 echo "$@"
}

info() {
    echo "$@"
}

if [ "$(id -u)" -ne 0 ]; then
    fail Error: Run this as root
fi

# Download Debian security update package list
PACKAGES="$(curl -s 'http://security-cdn.debian.org/debian-security/dists/buster/updates/main/binary-amd64/Packages.xz' | unxz -c)"

INSTALLED_VER_FILE="$HOME/.chromium-version"

DEBIAN_SECURITY_PREFIX=http://security.debian.org/debian-security/

# Find version for chromium and chromium-common
CHROMIUM="$(echo "$PACKAGES" | sed -n '/Package: chromium$/,/^$/p')"
CHROMIUM_VERSION="$(echo "$CHROMIUM" | grep 'Version:' | awk -F: '{print $2}' | xargs)"

CHROMIUM_COMMON="$(echo "$PACKAGES" | sed -n '/Package: chromium-common$/,/^$/p')"
CHROMIUM_COMMON_VERSION="$(echo "$CHROMIUM_COMMON" | grep 'Version:' | awk -F: '{print $2}' | xargs)"

if [ "$CHROMIUM_VERSION" != "$CHROMIUM_COMMON_VERSION" ]; then
    fail "Version mismatch between chromium ($CHROMIUM_VERSION) and chromium-common ($CHROMIUM_COMMON_VERSION)"
fi

info Latest version of Chromium: "$CHROMIUM_VERSION"

if [ -f "$INSTALLED_VER_FILE" ]; then
    if ! CURRENT_VERSION="$(cat "$INSTALLED_VER_FILE")"; then
        warn Could not read current version file
        CURRENT_VERSION=0
    fi
    info Installed version of Chromium: "$CURRENT_VERSION"
else
    info Installed version of Chromium: None
    CURRENT_VERSION=0
fi

if [ "$CURRENT_VERSION" = "$CHROMIUM_VERSION" ]; then
    info Chrome is up to date
    exit 0
fi

CHROMIUM_PATH="$(echo "$CHROMIUM" | grep 'Filename:' | awk -F: '{print $2}' | xargs)"
CHROMIUM_URL="$DEBIAN_SECURITY_PREFIX""$CHROMIUM_PATH"
CHROMIUM_COMMON_PATH="$(echo "$CHROMIUM_COMMON" | grep 'Filename:' | awk -F: '{print $2}' | xargs)"
CHROMIUM_COMMON_URL="$DEBIAN_SECURITY_PREFIX""$CHROMIUM_COMMON_PATH"

info Downloading Chromium and Chromium common version "$CHROMIUM_VERSION"

curl -Lso /tmp/chromium-"$CHROMIUM_VERSION".deb "$CHROMIUM_URL"
curl -Lso /tmp/chromium-common-"$CHROMIUM_VERSION"-common.deb "$CHROMIUM_COMMON_URL"

info Backing up dpkg status
if [ -f /tmp/status-"$CHROMIUM_VERSION".patch ]; then
    rm /tmp/status-"$CHROMIUM_VERSION".patch
fi

# Backup dpkg status
cp /var/lib/dpkg/status /tmp/status-"$CHROMIUM_VERSION" || fail Could not back up original dpkg status

info Installing chromium and chromium common version "$CHROMIUM_VERSION"
dpkg -i /tmp/chromium-"$CHROMIUM_VERSION".deb /tmp/chromium-common-"$CHROMIUM_VERSION"-common.deb >/dev/null 2>&1 || fail Could not install packages

info Removing Chromium from dpkg registry
# Remove the record from the debian package manager status
cp /var/lib/dpkg/status /var/lib/dpkg/status-chromium-"$CHROMIUM_VERSION" >/dev/null 2>&1 || fail Could not backup dpkg status
diff -u /var/lib/dpkg/status /tmp/status-"$CHROMIUM_VERSION" | tee /tmp/status-"$CHROMIUM_VERSION".patch > /dev/null 2>&1 || fail Could not create dpkg status patch
patch -d/ -p0 -i /tmp/status.patch >/dev/null 2>&1 || fail Could not patch dpkg status

info Saving chromium version
# Save the new version
echo "$CHROMIUM_VERSION" | tee "$INSTALLED_VER_FILE" >/dev/null 2>&1 || warn Could not save Chromium version
info Upgrade complete