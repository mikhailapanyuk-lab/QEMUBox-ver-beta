#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
QEMU_SRC="${ROOT_DIR}/qemu-src"
BUILD_DIR="${ROOT_DIR}/build-ios"
INSTALL_DIR="${ROOT_DIR}/qemu-ios"
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CC="$(xcrun --sdk iphoneos -f clang)"

CFLAGS="-isysroot ${IOS_SDK} -arch arm64 -miphoneos-version-min=16.0 -fPIC"
LDFLAGS="-isysroot ${IOS_SDK} -arch arm64 -miphoneos-version-min=16.0"

mkdir -p "${BUILD_DIR}" "${INSTALL_DIR}"
cd "${QEMU_SRC}"

# Apply patches if any
if [ -d "${ROOT_DIR}/qemu-patches" ]; then
  for p in "${ROOT_DIR}/qemu-patches"/*.patch; do
    [ -e "$p" ] || break
    echo "Applying patch: $p"
    patch -p1 < "$p"
  done
fi

PKG_CONFIG_PATH="" ./configure \
  --prefix="${INSTALL_DIR}" \
  --cc="${CC}" \
  --extra-cflags="${CFLAGS}" \
  --extra-ldflags="${LDFLAGS}" \
  --target-list=aarch64-softmmu,arm-softmmu,x86_64-softmmu \
  --enable-tcg \
  --disable-sdl \
  --disable-gtk \
  --disable-docs \
  --disable-guest-agent

make -j$(sysctl -n hw.ncpu)
make install
