#!/bin/bash
#
# Remove openmediavault-imagecheck. Run AS ROOT on the OMV server.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root (sudo bash uninstall.sh)." >&2
    exit 1
fi

echo "==> Removing openmediavault-imagecheck"
rm -f /usr/share/openmediavault/engined/rpc/imagecheck.inc
rm -f /usr/sbin/omv-imagecheck
rm -f /etc/cron.d/openmediavault-imagecheck
rm -f /var/lib/openmediavault/imagecheck.json

echo "==> Restarting openmediavault-engined..."
systemctl restart openmediavault-engined

echo "Removed."
