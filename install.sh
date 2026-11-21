#!/usr/bin/env sh
# Universal multi-OS / multi-distro / multi-arch installer for agentd (https://github.com/wrpbr/agentd).
# Works both when run from a downloaded release directory AND when piped/run directly from the repo
# (automatically downloads and verifies SHA256SUMS + the prebuilt binary package from GitHub Releases).
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd || pwd)"
VERSION="${AGENTD_VERSION:-${SAFEGUARD_VERSION:-0.1.0}}"
RELEASE_BASE="${AGENTD_RELEASE_BASE:-https://github.com/wrpbr/agentd/releases/download/v${VERSION}}"
ARCH_RAW="$(uname -m 2>/dev/null || echo x86_64)"
OS_RAW="$(uname -s 2>/dev/null || echo Linux)"

case "$ARCH_RAW" in
  x86_64|amd64)
    ARCH="amd64"
    DEB_ARCH="amd64"
    RPM_ARCH="x86_64"
    PKG_ARCH="x86_64"
    APK_ARCH="x86_64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    DEB_ARCH="arm64"
    RPM_ARCH="aarch64"
    PKG_ARCH="aarch64"
    APK_ARCH="aarch64"
    ;;
  *)
    echo "[x] Unsupported architecture: $ARCH_RAW" >&2
    exit 1
    ;;
esac

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    "$@"
  fi
}

verify_sha256() {
  DIR="$1"
  FILE="$2"
  if [ ! -f "$DIR/SHA256SUMS" ]; then
    curl -fsSL "$RELEASE_BASE/SHA256SUMS" -o "$DIR/SHA256SUMS"
  fi
  EXPECTED="$(awk -v f="$FILE" '$2 == f || $2 == "*"f {print $1}' "$DIR/SHA256SUMS" | head -n 1)"
  if [ -z "$EXPECTED" ]; then
    echo "[x] Checksum for $FILE not found in SHA256SUMS" >&2
    exit 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL="$(sha256sum "$DIR/$FILE" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    ACTUAL="$(shasum -a 256 "$DIR/$FILE" | awk '{print $1}')"
  else
    echo "[x] Neither sha256sum nor shasum found to verify $FILE" >&2
    exit 1
  fi
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "[x] SHA-256 mismatch for $FILE (expected $EXPECTED, got $ACTUAL)" >&2
    exit 1
  fi
  echo "[+] Verified SHA-256 for $FILE ($ACTUAL)"
}

fetch_artifact() {
  ARTIFACT="$1"
  if [ -f "$SCRIPT_DIR/$ARTIFACT" ]; then
    if [ -f "$SCRIPT_DIR/SHA256SUMS" ]; then
      verify_sha256 "$SCRIPT_DIR" "$ARTIFACT" >&2
    fi
    printf '%s\n' "$SCRIPT_DIR/$ARTIFACT"
    return 0
  fi
  TMP_DL="${AGENTD_TMP_DIR:-$(mktemp -d)}"
  echo "[+] Downloading $RELEASE_BASE/$ARTIFACT ..." >&2
  curl -fsSL "$RELEASE_BASE/$ARTIFACT" -o "$TMP_DL/$ARTIFACT"
  verify_sha256 "$TMP_DL" "$ARTIFACT" >&2
  printf '%s\n' "$TMP_DL/$ARTIFACT"
}

install_from_tarball() {
  TARBALL="$1"
  shift
  DEST="${AGENTD_PREFIX:-${SAFEGUARD_PREFIX:-$HOME/.local/share/agentd}}"
  mkdir -p "$DEST"
  tar -xzf "$TARBALL" -C "$DEST" --strip-components=1
  "$DEST/safeguard-install" --native --native-bin-dir "$DEST" --no-feature-ui "$@"
}

if [ "$OS_RAW" = "Darwin" ]; then
  MAC_TAR="$(fetch_artifact "agentd-${VERSION}-macos-universal.tar.gz")"
  TMP_MAC="$(mktemp -d)"
  tar -xzf "$MAC_TAR" -C "$TMP_MAC" --strip-components=1
  sh "$TMP_MAC/install-macos.sh" "$@"
  rm -rf "$TMP_MAC"
  exit 0
fi

TAR_NAME="agentd-${VERSION}-linux-${ARCH}.tar.gz"
DEB_NAME="agentd_${VERSION}_${DEB_ARCH}.deb"
RPM_NAME="agentd-${VERSION}-1.${RPM_ARCH}.rpm"
ARCH_NAME="agentd-${VERSION}-1-${PKG_ARCH}.pkg.tar.zst"
APK_NAME="agentd-${VERSION}-r0.${APK_ARCH}.apk"

if [ "${AGENTD_PORTABLE:-${SAFEGUARD_PORTABLE:-0}}" = "1" ]; then
  TAR_FILE="$(fetch_artifact "$TAR_NAME")"
  install_from_tarball "$TAR_FILE" "$@"
  exit 0
fi

if command -v pacman >/dev/null 2>&1 && ( [ -f "$SCRIPT_DIR/$ARCH_NAME" ] || [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1 ); then
  ARCH_FILE="$(fetch_artifact "$ARCH_NAME")"
  run_privileged pacman -U --noconfirm "$ARCH_FILE"
  /usr/bin/agentd-install --native --native-bin-dir /usr/lib/safeguard --no-feature-ui "$@"
  exit 0
fi

if command -v dpkg >/dev/null 2>&1 && ( [ -f "$SCRIPT_DIR/$DEB_NAME" ] || [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1 ); then
  DEB_FILE="$(fetch_artifact "$DEB_NAME")"
  run_privileged dpkg -i "$DEB_FILE"
  /usr/bin/agentd-install --native --native-bin-dir /usr/lib/safeguard --no-feature-ui "$@"
  exit 0
fi

if command -v rpm >/dev/null 2>&1 && ( [ -f "$SCRIPT_DIR/$RPM_NAME" ] || [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1 ); then
  RPM_FILE="$(fetch_artifact "$RPM_NAME")"
  run_privileged rpm -Uvh --replacepkgs "$RPM_FILE"
  /usr/bin/agentd-install --native --native-bin-dir /usr/lib/safeguard --no-feature-ui "$@"
  exit 0
fi

if command -v apk >/dev/null 2>&1 && ( [ -f "$SCRIPT_DIR/$APK_NAME" ] || [ "$(id -u)" -eq 0 ] || command -v sudo >/dev/null 2>&1 ); then
  APK_FILE="$(fetch_artifact "$APK_NAME")"
  run_privileged apk add --allow-untrusted "$APK_FILE"
  /usr/bin/agentd-install --native --native-bin-dir /usr/lib/safeguard --no-feature-ui "$@"
  exit 0
fi

TAR_FILE="$(fetch_artifact "$TAR_NAME")"
install_from_tarball "$TAR_FILE" "$@"
