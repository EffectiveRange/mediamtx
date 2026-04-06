#!/bin/bash

set -e

VERSION="$1"
ARCH="$2"

if [ -z "$VERSION" ] || [ -z "$ARCH" ]; then
  echo "Usage: $0 <version> <arch>"
  exit 1
fi

ARCHIVE="binaries/mediamtx_${VERSION}_linux_${ARCH}.tar.gz"
if [ ! -f "$ARCHIVE" ]; then
  echo "Archive not found: $ARCHIVE"
  exit 1
fi

PACKAGE_ROOT="dist"
DEBIAN_DIR="$PACKAGE_ROOT/DEBIAN"
BINARY_DIR="$PACKAGE_ROOT/usr/local/bin"
CONFIG_DIR="$PACKAGE_ROOT/etc/mediamtx"
SERVICE_DIR="$PACKAGE_ROOT/lib/systemd/system"

rm -rf "$PACKAGE_ROOT"
mkdir -p "$DEBIAN_DIR"
mkdir -p "$BINARY_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$SERVICE_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tar -xzf "$ARCHIVE" -C "$TMP_DIR"

if [ ! -f "$TMP_DIR/mediamtx" ]; then
  echo "Extracted binary not found in archive: $ARCHIVE"
  exit 1
fi

cp "$TMP_DIR/mediamtx" "$BINARY_DIR/mediamtx"
cp "$TMP_DIR/mediamtx.yml" "$CONFIG_DIR/mediamtx.yml"

chmod 755 "$BINARY_DIR"/*

cp debian/mediamtx.service "$SERVICE_DIR"

cat > "$DEBIAN_DIR/control" <<EOF
Package: mediamtx
Version: $VERSION
Section: base
Priority: optional
Architecture: ${ARCH}
Maintainer: Effective Range <info@effective-range.com>
Description: MediaMTX is a ready-to-use and zero-dependency live media server and media proxy. It has been conceived as a "media router" that routes media streams from one end to the other, with a focus on efficiency and portability.
EOF

cd "$PACKAGE_ROOT"

dpkg-deb --build . "mediamtx_${VERSION}_${ARCH}.deb"
