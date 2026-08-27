#!/bin/bash
set -e

# This script downloads large QEMU binaries and OpenCore firmware from release assets
# into the appropriate locations on-device. Intended to be run from postinst during package install.

RELEASE_BASE="https://github.com/mikhailapanyuk-lab/QEMUBox-ver-beta/releases/download/v0.1"
BIN_DIR="/var/mobile/qemu/bin"
FW_DIR="/var/mobile/qemu/firmware"
LOG="/var/log/qemubox-install.log"

mkdir -p "$BIN_DIR"
mkdir -p "$FW_DIR"

echo "[qemubox] download_binaries.sh started at $(date)" >> "$LOG"

download_and_verify() {
    local url="$1"
    local out="$2"
    local sha256_expected="$3"

    echo "[qemubox] downloading $url -> $out" >> "$LOG"
    curl -L --fail -o "$out" "$url"
    if [ -n "$sha256_expected" ]; then
        echo "[qemubox] verifying checksum for $out" >> "$LOG"
        if command -v sha256sum >/dev/null 2>&1; then
            got=$(sha256sum "$out" | awk '{print $1}')
        elif command -v shasum >/dev/null 2>&1; then
            got=$(shasum -a 256 "$out" | awk '{print $1}')
        else
            echo "[qemubox] warning: no sha256 tool available on device, skipping checksum verification" >> "$LOG"
            return 0
        fi
        if [ "$got" != "$sha256_expected" ]; then
            echo "[qemubox] checksum mismatch for $out: expected $sha256_expected got $got" >> "$LOG"
            return 1
        fi
    fi
    return 0
}

# Files to download (placeholders - ensure these artifacts are uploaded to the repo Releases)
QEMU_SYSTEM_URL="$RELEASE_BASE/qemu-system-aarch64"
QEMU_IMG_URL="$RELEASE_BASE/qemu-img"

# Attempt to detect latest OpenCore release automatically from the official repo if not supplied via RELEASE_BASE
# Preferred upstream: acidanthera/OpenCorePkg
OPENCORE_URL=""

if [ -z "$OPENCORE_URL" ]; then
    echo "[qemubox] attempting to locate latest OpenCore release via GitHub API" >> "$LOG"
    # Query GitHub API for latest release and extract a suitable OpenCore artifact (zip)
    api_url="https://api.github.com/repos/acidanthera/OpenCorePkg/releases/latest"
    oc_url=$(curl -s "$api_url" | grep -i '"browser_download_url":' | grep -i -E 'OpenCore.*zip|OpenCore.*RELEASE' | head -n1 | cut -d '"' -f4 || true)
    if [ -n "$oc_url" ]; then
        OPENCORE_URL="$oc_url"
        echo "[qemubox] found OpenCore asset: $OPENCORE_URL" >> "$LOG"
    else
        # Fallback to our release asset name
        OPENCORE_URL="$RELEASE_BASE/opencore-firmware.zip"
        echo "[qemubox] could not auto-detect OpenCore release, falling back to $OPENCORE_URL" >> "$LOG"
    fi
fi

# Optional: checksums (fill these in when artifacts are uploaded to Releases)
QEMU_SYSTEM_SHA=""
QEMU_IMG_SHA=""
OPENCORE_SHA=""

# Download qemu-system
if ! download_and_verify "$QEMU_SYSTEM_URL" "$BIN_DIR/qemu-system-aarch64" "$QEMU_SYSTEM_SHA"; then
    echo "[qemubox] failed to download or verify qemu-system-aarch64" >> "$LOG"
fi
chmod 755 "$BIN_DIR/qemu-system-aarch64" || true

# Download qemu-img
if ! download_and_verify "$QEMU_IMG_URL" "$BIN_DIR/qemu-img" "$QEMU_IMG_SHA"; then
    echo "[qemubox] failed to download or verify qemu-img" >> "$LOG"
fi
chmod 755 "$BIN_DIR/qemu-img" || true

# Download OpenCore firmware
TMPZIP="/tmp/opencore-firmware.zip"
if ! download_and_verify "$OPENCORE_URL" "$TMPZIP" "$OPENCORE_SHA"; then
    echo "[qemubox] failed to download or verify OpenCore firmware from $OPENCORE_URL" >> "$LOG"
else
    echo "[qemubox] extracting OpenCore firmware to $FW_DIR" >> "$LOG"
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "$TMPZIP" -d "$FW_DIR" >> "$LOG" 2>&1 || true
    else
        # Try to use jar if present (busybox unzip unlikely); otherwise just move the zip
        mv "$TMPZIP" "$FW_DIR/" || true
    fi
    rm -f "$TMPZIP"
fi

# Ensure ownership is mobile:mobile
chown -R mobile:mobile /var/mobile/qemu || true
chmod -R 755 /var/mobile/qemu/bin || true

# Mark that binaries were downloaded
touch /var/mobile/qemu/.binaries_installed

echo "[qemubox] download_binaries.sh finished at $(date)" >> "$LOG"
