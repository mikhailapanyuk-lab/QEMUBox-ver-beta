#!/bin/bash
set -e

# This script downloads large QEMU binaries and OpenCore firmware from the GitHub release assets
# into the appropriate locations on-device. It is intended to be run from postinst during package install.

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
        sha256sum "$out" | awk '{print $1}' > "$out.sha256"
        got=$(cat "$out.sha256")
        if [ "$got" != "$sha256_expected" ]; then
            echo "[qemubox] checksum mismatch for $out: expected $sha256_expected got $got" >> "$LOG"
            return 1
        fi
    fi
    return 0
}

# Files to download (placeholders - ensure these assets are uploaded to the repo Releases)
QEMU_SYSTEM_URL="$RELEASE_BASE/qemu-system-aarch64"
QEMU_IMG_URL="$RELEASE_BASE/qemu-img"
# OpenCore archive (zip of the firmware files expected by QEMUBox)
OPENCORE_URL="$RELEASE_BASE/opencore-firmware.zip"

# Optional: checksums (fill these in when you upload artifacts)
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
    echo "[qemubox] failed to download or verify OpenCore firmware" >> "$LOG"
else
    echo "[qemubox] extracting OpenCore firmware to $FW_DIR" >> "$LOG"
    unzip -o "$TMPZIP" -d "$FW_DIR" >> "$LOG" 2>&1 || true
    rm -f "$TMPZIP"
fi

# Ensure ownership is mobile:mobile
chown -R mobile:mobile /var/mobile/qemu || true
chmod -R 755 /var/mobile/qemu/bin || true

echo "[qemubox] download_binaries.sh finished at $(date)" >> "$LOG"
