#!/bin/bash

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

get_version() {
    SEARCH="$1"
    PACKAGE="$(echo "$PACKAGES" | sed -n '/Package: '"$SEARCH"'$/,/^$/p')"
    VERSION="$(echo "$PACKAGE" | grep 'Version:' | awk -F: '{print $2}' | xargs)"
    FILENAME="$(echo "$PACKAGE" | grep 'Filename:' | awk -F: '{print $2}' | xargs)"
}

check_version_match() {
    if [ "$1" != "$2" ]; then
        fail Version mismatch between "$1" and "$2"
    fi
}

download() {
    URL="$DEBIAN_SECURITY_PREFIX""$1"
    info Downloading package "$2"
    curl -Lso /tmp/"$2"-"$CHROMIUM_VERSION".deb "$URL" || fail Could not download "$2" package
}

install_chromium() {
    for i in "${@}"; do
        ARGS+=(/tmp/"$i"-"$CHROMIUM_VERSION".deb)
        INSTALL_PACKAGES+=("$i")
    done
    info Installing packages "${INSTALL_PACKAGES[@]}"
    dpkg -i "${ARGS[@]}" >/dev/null || fail Could not install packages
}


check_cmd() {
    if ! command -v "$@" >/dev/null 2>&1; then fail "Command '${*}' missing - do you need to install it?"; fi
}

check_cmd diff
check_cmd curl
check_cmd sed
check_cmd awk
check_cmd grep
check_cmd tee
check_cmd dpkg
check_cmd patch


if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        warn This must be run as root - attempting to use sudo
        if ! sudo "$0" "$@"; then
            fail This must be run as root - e.g. "'sudo $0'"
        fi
        # Was successful as sudo so just exit
        exit
    fi
    fail This must be run as root
fi

FORCE=0
if [ -n "$1" ]; then
    FORCE=1
    warn "Ignoring version check and forcing reinstallation"
fi

# Download Debian security update package list
PACKAGES="$(curl -s 'http://security-cdn.debian.org/debian-security/dists/buster/updates/main/binary-amd64/Packages.xz' | unxz -c)"

INSTALLED_VER_FILE="$HOME/.chromium-version"

DEBIAN_SECURITY_PREFIX=http://security.debian.org/debian-security/

get_version chromium
CHROMIUM_VERSION="$VERSION"
CHROMIUM_PATH="$FILENAME"

get_version chromium-common
CHROMIUM_COMMON_VERSION="$VERSION"
CHROMIUM_COMMON_PATH="$FILENAME"

get_version chromium-sandbox
CHROMIUM_SANDBOX_VERSION="$VERSION"
CHROMIUM_SANDBOX_PATH="$FILENAME"

get_version chromium-l10n
CHROMIUM_L10N_VERSION="$VERSION"
CHROMIUM_L10N_PATH="$FILENAME"

get_version chromium-driver
CHROMIUM_DRIVER_VERSION="$VERSION"
CHROMIUM_DRIVER_PATH="$FILENAME"

check_version_match "$CHROMIUM_VERSION" "$CHROMIUM_COMMON_VERSION"
check_version_match "$CHROMIUM_VERSION" "$CHROMIUM_SANDBOX_VERSION"
check_version_match "$CHROMIUM_VERSION" "$CHROMIUM_L10N_VERSION"
check_version_match "$CHROMIUM_VERSION" "$CHROMIUM_DRIVER_VERSION"

info Latest version of Chromium"    ": "$CHROMIUM_VERSION"

if [ -f "$INSTALLED_VER_FILE" ]; then
    if ! CURRENT_VERSION="$(cat "$INSTALLED_VER_FILE")"; then
        warn Could not read current version file
        CURRENT_VERSION=0
    fi
    info Installed version of Chromium : "$CURRENT_VERSION"
else
    info Installed version of Chromium : None
    CURRENT_VERSION=0
fi

if [ "$FORCE" = 0 ] && [ "$CURRENT_VERSION" = "$CHROMIUM_VERSION" ]; then
    info Chromium is up to date
    exit 0
fi

download "$CHROMIUM_PATH" chromium
download "$CHROMIUM_COMMON_PATH" chromium-common
download "$CHROMIUM_SANDBOX_PATH" chromium-sandbox
download "$CHROMIUM_L10N_PATH" chromium-l10n
download "$CHROMIUM_DRIVER_PATH" chromium-driver


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

install_chromium chromium chromium-common chromium-sandbox chromium-l10n chromium-driver

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
