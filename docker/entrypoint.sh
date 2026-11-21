#!/bin/sh
set -eu

HOME_DIR="${HOME:-/var/lib/agentd}"
POLICY_DIR="$HOME_DIR/.claude/.safeguard/policy"
PACKAGES_DIR="$POLICY_DIR/installed"
SOCKET_PATH="${AGENTD_DAEMON_SOCKET:-${SAFEGUARD_DAEMON_SOCKET:-/run/agentd/safeguard-daemon.sock}}"

mkdir -p "$PACKAGES_DIR" "$POLICY_DIR/packages"

# Install default hooks and features in container $HOME_DIR if not yet initialized
if [ ! -f "$HOME_DIR/.claude/.safeguard/features.env" ]; then
  /usr/local/bin/agentd-install \
    --native \
    --native-bin-dir /usr/local/lib/agentd \
    --no-enable-systemd-user \
    --no-feature-ui \
    --agents "${AGENTD_INSTALL_AGENTS:-all}" >/dev/null 2>&1 || true
fi

# Seed the 5 verified defense rule packages from the bundled image store so
# the daemon immediately enforces all 5 packages even offline.
for pkg in /usr/local/share/agentd/rules/core/*.json; do
  if [ -f "$pkg" ]; then
    base="$(basename "$pkg")"
    if [ ! -f "$PACKAGES_DIR/$base" ]; then
      cp "$pkg" "$PACKAGES_DIR/$base"
    fi
  fi
done

if [ ! -f "$POLICY_DIR/catalogs.json" ] && [ -f /usr/local/share/agentd/rules/catalogs/github-core.json ]; then
  cat > "$POLICY_DIR/catalogs.json" <<'EOF'
{
  "version": 1,
  "sources": [
    {
      "id": "github-core",
      "name": "agentd Official Core Rules",
      "url": "https://raw.githubusercontent.com/wrpbr/agentd/main/rules/catalogs/github-core.json",
      "enabled": true
    },
    {
      "id": "agentalog-core",
      "name": "Agentalog Verified Defense Catalog",
      "url": "https://agentalog.com/api/agentd/catalog",
      "enabled": true
    }
  ]
}
EOF
  cp /usr/local/share/agentd/rules/catalogs/github-core.json "$POLICY_DIR/catalog-cache.json"
fi

# Optional online catalog refresh when AGENTD_AUTO_SYNC=1
if [ "${AGENTD_AUTO_SYNC:-0}" = "1" ]; then
  if [ -n "${AGENTD_CATALOG_URL:-}" ]; then
    /usr/local/bin/agentd --catalog-add "$AGENTD_CATALOG_URL" >/dev/null 2>&1 || true
  fi
  /usr/local/bin/agentd --catalog-sync >/dev/null 2>&1 || true
  /usr/local/bin/agentd \
    --catalog-install agent-governance-core \
    --catalog-install secret-exfiltration-defense \
    --catalog-install production-db-defense \
    --catalog-install supply-chain-defense \
    --catalog-install mcp-tool-defense >/dev/null 2>&1 || true
fi

# Auto-provision host agent hooks when the host's $HOME is mounted at /host-home
HOST_MOUNT="${AGENTD_HOST_MOUNT:-/host-home}"
if [ -d "$HOST_MOUNT" ] && [ "${AGENTD_AUTO_WIRE_HOST:-1}" = "1" ]; then
  HOST_REAL_HOME="${AGENTD_HOST_HOME_PATH:-$HOST_MOUNT}"
  HOST_UG="$(stat -c '%u:%g' "$HOST_MOUNT" 2>/dev/null || echo '0:0')"
  HOST_SHARE="$HOST_MOUNT/.local/share/agentd"
  mkdir -p "$HOST_SHARE" "$HOST_MOUNT/.local/bin" "$HOST_MOUNT/.claude/hooks"
  cp -af /usr/local/lib/agentd/* "$HOST_SHARE/"
  HOME="$HOST_MOUNT" /usr/local/bin/agentd-install \
    --native \
    --native-bin-dir "$HOST_SHARE" \
    --no-enable-systemd-user \
    --no-feature-ui \
    --agents "${AGENTD_INSTALL_AGENTS:-all}" >/dev/null 2>&1 || true

  # Rewrite symlinks so they resolve on the host filesystem ($HOST_REAL_HOME)
  for link in "$HOST_MOUNT/.claude/hooks/"* "$HOST_MOUNT/.local/bin/"*; do
    if [ -L "$link" ]; then
      target="$(readlink "$link" || true)"
      case "$target" in
        "$HOST_SHARE/"*)
          bin_name="${target##*/}"
          ln -snf "$HOST_REAL_HOME/.local/share/agentd/$bin_name" "$link"
          ;;
      esac
    fi
  done

  chown -R "$HOST_UG" \
    "$HOST_MOUNT/.local" \
    "$HOST_MOUNT/.claude" \
    "$HOST_MOUNT/.codex" \
    "$HOST_MOUNT/.pi" \
    "$HOST_MOUNT/.gemini" \
    "$HOST_MOUNT/.cursor" 2>/dev/null || true
  echo "agentd-entrypoint: wired host agent hooks in $HOST_REAL_HOME" >&2
fi

case "$SOCKET_PATH" in
  tcp://*) ;;
  *)
    SOCK_DIR="$(dirname "$SOCKET_PATH")"
    SOCK_BASE="$(basename "$SOCKET_PATH")"
    mkdir -p "$SOCK_DIR"
    chmod 0777 "$SOCK_DIR" 2>/dev/null || true
    if [ "$SOCK_BASE" = "safeguard-daemon.sock" ]; then
      ln -snf "safeguard-daemon.sock" "$SOCK_DIR/agentd-daemon.sock" 2>/dev/null || true
    elif [ "$SOCK_BASE" = "agentd-daemon.sock" ]; then
      ln -snf "agentd-daemon.sock" "$SOCK_DIR/safeguard-daemon.sock" 2>/dev/null || true
    fi
    ;;
esac

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exec /usr/local/bin/agentd-daemon --socket "$SOCKET_PATH"
