#!/usr/bin/env bash
set -euo pipefail

# Simple packaging script for QEMUBox runtime (.deb)
# Usage: run from repository root on macOS/Linux with dpkg-deb available
# It expects built qemu binaries in QEMU/qemu-ios/bin and jit_test at repo root (built by clang)

PKGROOT=$(mktemp -d /tmp/qemu_pkg.XXXX)
DEBIAN_DIR="$PKGROOT/DEBIAN"
BIN_DIR="$PKGROOT/usr/local/bin"

mkdir -p "$DEBIAN_DIR" "$BIN_DIR"

# Replace these with actual built binaries
if [ ! -f "QEMU/qemu-ios/bin/qemu-system-aarch64" ]; then
  echo "Error: qemu-system-aarch64 not found in QEMU/qemu-ios/bin. Build QEMU first using QEMU/build-qemu-ios.sh" >&2
  exit 1
fi

cp QEMU/qemu-ios/bin/qemu-system-aarch64 "$BIN_DIR/"

if [ -f "jit_test" ]; then
  cp jit_test "$BIN_DIR/"
fi

chmod 755 "$BIN_DIR/qemu-system-aarch64" || true
chmod 755 "$BIN_DIR/jit_test" || true

cat > "$DEBIAN_DIR/control" <<EOF
Package: com.qemubox.qemu-runtime
Name: QEMUBox QEMU Runtime
Version: 1.0
Architecture: iphoneos-arm
Maintainer: QEMUBox <noreply@example.com>
Depends: libc6
Section: utils
Priority: optional
Description: QEMU runtime for QEMUBox (TCG enabled). Provides qemu-system-aarch64 and jit_test helper for JIT detection.
EOF

# Optional: postinst to set permissions or symlinks
cat > "$DEBIAN_DIR/postinst" <<'POST'
#!/bin/sh
set -e
chmod 755 /usr/local/bin/qemu-system-aarch64 || true
chmod 755 /usr/local/bin/jit_test || true
exit 0
POST
chmod 755 "$DEBIAN_DIR/postinst"

# Build .deb
OUT_DEB="qemu-ios_1.0.deb"
dpkg-deb --build "$PKGROOT" "$OUT_DEB"

echo "Built package: $OUT_DEB"

echo "Cleaning up"
rm -rf "$PKGROOT"
