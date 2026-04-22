#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

VERSION="${1:-}"
ARCH="${2:-}"
VARIANT="${3:-standard}"

if [ -z "$VERSION" ] || [ -z "$ARCH" ]; then
  echo "Usage: $0 <version> <arch> [standard|rpi]"
  exit 1
fi

PACKAGE_NAME="mediamtx"
CONFIG_SOURCE="$REPO_ROOT/mediamtx.yml"
SERVICE_SOURCE="$REPO_ROOT/debian/mediamtx.service"
SERVICE_NAME="mediamtx.service"

case "$VARIANT" in
  standard|"")
    ;;
  rpi|mediamtx-rpi)
    PACKAGE_NAME="mediamtx-rpi"
    CONFIG_SOURCE="$REPO_ROOT/mediamtx-rpi.yml"
    ;;
  *)
    echo "Invalid variant: $VARIANT"
    echo "Usage: $0 <version> <arch> [standard|rpi]"
    exit 1
    ;;
esac

ARCHIVE="$REPO_ROOT/binaries/mediamtx_v${VERSION}_linux_${ARCH}.tar.gz"
if [ ! -f "$ARCHIVE" ]; then
  echo "Archive not found: $ARCHIVE"
  exit 1
fi

if [ ! -f "$CONFIG_SOURCE" ]; then
  echo "Config source not found: $CONFIG_SOURCE"
  exit 1
fi

if [ ! -f "$SERVICE_SOURCE" ]; then
  echo "Service source not found: $SERVICE_SOURCE"
  exit 1
fi

PACKAGE_ROOT="$REPO_ROOT/dist"
DEBIAN_DIR="$PACKAGE_ROOT/DEBIAN"
BINARY_DIR="$PACKAGE_ROOT/usr/local/bin"
CONFIG_DIR="$PACKAGE_ROOT/etc/mediamtx"
SERVICE_DIR="$PACKAGE_ROOT/lib/systemd/system"

rm -rf "$PACKAGE_ROOT"
mkdir -p "$DEBIAN_DIR" "$BINARY_DIR" "$CONFIG_DIR" "$SERVICE_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

tar -xzf "$ARCHIVE" -C "$TMP_DIR"

if [ ! -f "$TMP_DIR/mediamtx" ]; then
  echo "Extracted binary not found in archive: $ARCHIVE"
  exit 1
fi

cp "$TMP_DIR/mediamtx" "$BINARY_DIR/mediamtx"
cp "$CONFIG_SOURCE" "$CONFIG_DIR/mediamtx.yml"
chmod 755 "$BINARY_DIR/mediamtx"

cp "$SERVICE_SOURCE" "$SERVICE_DIR/$SERVICE_NAME"

if [ "$VARIANT" = "rpi" ] || [ "$VARIANT" = "mediamtx-rpi" ]; then
  cat > "$BINARY_DIR/init-mediamtx-rpi.sh" <<'EOF'
#!/bin/sh
set -e

sed -ri 's/camera_auto_detect=1/camera_auto_detect=0/g' /boot/firmware/config.txt
echo dtoverlay=imx708,cam0 | tee -a /boot/firmware/config.txt
echo dtoverlay=imx708,cam1 | tee -a /boot/firmware/config.txt
systemctl enable mediamtx.service

reboot

exit 0
EOF

  chmod 755 "$BINARY_DIR/init-mediamtx-rpi.sh"
fi

cat > "$DEBIAN_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: base
Priority: optional
Architecture: $ARCH
Maintainer: Effective Range <info@effective-range.com>
Description: MediaMTX is a ready-to-use and zero-dependency live media server and media proxy. It has been conceived as a "media router" that routes media streams from one end to the other, with a focus on efficiency and portability.
EOF

(
  cd "$PACKAGE_ROOT"
  dpkg-deb --build . "${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
)