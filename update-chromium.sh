#!/bin/sh

fail() {
    >&2 echo '[Failure]' "$@"
    exit 1
}

warn() {
    >&2 echo '[Warning]' "$@"
}

info() {
    echo '[Info]' "$@"
}

if [ "$(id -u)" -ne 0 ]; then
    fail This must be run as root
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
    info Chromium is up to date
    exit 0
fi

CHROMIUM_PATH="$(echo "$CHROMIUM" | grep 'Filename:' | awk -F: '{print $2}' | xargs)"
CHROMIUM_URL="$DEBIAN_SECURITY_PREFIX""$CHROMIUM_PATH"
CHROMIUM_COMMON_PATH="$(echo "$CHROMIUM_COMMON" | grep 'Filename:' | awk -F: '{print $2}' | xargs)"
CHROMIUM_COMMON_URL="$DEBIAN_SECURITY_PREFIX""$CHROMIUM_COMMON_PATH"

info Downloading Chromium "$CHROMIUM_VERSION"

curl -Lso /tmp/chromium-"$CHROMIUM_VERSION".deb "$CHROMIUM_URL" || fail Could not download Chromium package
curl -Lso /tmp/chromium-common-"$CHROMIUM_VERSION".deb "$CHROMIUM_COMMON_URL" || fail Could not download Chromium Common package

PATCH_FILE=/tmp/status-chromium-"$CHROMIUM_VERSION".patch
BACKUP_FILE=/tmp/status-backup-chromium-"$CHROMIUM_VERSION"
RESTORE_FILE=/tmp/status-restore-chromium-"$CHROMIUM_VERSION"
DPKG_STATUS_FILE=/var/lib/dpkg/status

info Backing up dpkg status
if [ -f "$PATCH_FILE" ]; then
    rm "$PATCH_FILE" || warn Could not delete old patch file
fi

# Backup original dpkg status (we'll restore this one later)
cp "$DPKG_STATUS_FILE" "$RESTORE_FILE" || fail Could not back up original dpkg status

info Installing Chromium "$CHROMIUM_VERSION"
dpkg -i /tmp/chromium-"$CHROMIUM_VERSION".deb /tmp/chromium-common-"$CHROMIUM_VERSION".deb >/dev/null 2>&1 || fail Could not install packages

info Removing Chromium from dpkg status registry
# Backup the new status file in case it goes wrong - this is for manual repair
cp "$DPKG_STATUS_FILE" "$BACKUP_FILE" >/dev/null 2>&1 || fail Could not backup dpkg status
# Take a diff of the new status and the original (restore) file without chromium insalled
diff -u "$DPKG_STATUS_FILE" "$RESTORE_FILE" | tee "$PATCH_FILE" > /dev/null 2>&1 || fail Could not create dpkg status patch

patch -d/ -Np0 -i "$PATCH_FILE" "$DPKG_STATUS_FILE" >/dev/null || fail Could not patch dpkg status

info Saving chromium version
# Save the new version
echo "$CHROMIUM_VERSION" | tee "$INSTALLED_VER_FILE" >/dev/null 2>&1 || warn Could not save Chromium version
info Upgrade complete
