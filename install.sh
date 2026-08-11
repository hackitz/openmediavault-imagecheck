#!/bin/bash
#
# openmediavault-imagecheck installer (single-server, no .deb build required).
# Run this AS ROOT on the OMV server:
#
#     sudo bash install.sh
#
# It copies the plugin files into place, does a first check to warm the cache,
# and restarts the OMV engine daemon so the new RPC service is registered.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo bash install.sh)." >&2
    exit 1
fi

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

echo "==> Installing openmediavault-imagecheck from ${here}"

install -D -m 0644 \
    "${here}/usr/share/openmediavault/engined/rpc/imagecheck.inc" \
    /usr/share/openmediavault/engined/rpc/imagecheck.inc

install -D -m 0755 \
    "${here}/usr/sbin/omv-imagecheck" \
    /usr/sbin/omv-imagecheck

install -D -m 0644 \
    "${here}/etc/cron.d/openmediavault-imagecheck" \
    /etc/cron.d/openmediavault-imagecheck

mkdir -p /var/lib/openmediavault

echo "==> Sanity check: is Docker reachable as root?"
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
    echo "    WARNING: 'docker' is not reachable as root. The checker needs Docker."
    echo "    Install/verify Docker before relying on results."
fi

echo "==> Running a first check to warm the cache (this can take a bit)..."
/usr/sbin/omv-imagecheck --refresh || true

echo "==> Restarting openmediavault-engined to register the ImageCheck service..."
systemctl restart openmediavault-engined

echo
echo "Installed."
echo "Test the RPC directly with:"
echo "    omv-rpc -u admin 'ImageCheck' 'getStatus' | python3 -m json.tool"
echo "    omv-rpc -u admin 'ImageCheck' 'getUpdateList' '{\"start\":0,\"limit\":-1,\"sortfield\":null,\"sortdir\":null}'"
echo
echo "Inspect the raw cache any time with:"
echo "    omv-imagecheck --print"
