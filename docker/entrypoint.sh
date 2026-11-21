#!/bin/sh
set -eu

HOME_DIR="${HOME:-/var/lib/agentd}"
POLICY_DIR="$HOME_DIR/.claude/.safeguard/policy"
PACKAGES_DIR="$POLICY_DIR/installed"
SOCKET_PATH="${AGENTD_DAEMON_SOCKET:-${SAFEGUARD_DAEMON_SOCKET:-/run/agentd/agentd-daemon.sock}}"

mkdir -p "$PACKAGES_DIR" "$POLICY_DIR/packages"

# Install default hooks and features in $HOME_DIR if not yet initialized
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

case "$SOCKET_PATH" in
  tcp://*) ;;
  *)
    mkdir -p "$(dirname "$SOCKET_PATH")"
    ;;
esac

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exec /usr/local/bin/agentd-daemon --socket "$SOCKET_PATH"
