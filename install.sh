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

# Require OpenMediaVault 8 or newer (OMV 7 is end-of-life).
omv_ver="$(dpkg-query -W -f='${Version}' openmediavault 2>/dev/null || true)"
omv_major="${omv_ver%%.*}"
if [ -z "${omv_ver}" ]; then
    echo "WARNING: could not detect an OpenMediaVault package; is this an OMV host?" >&2
elif ! [ "${omv_major}" -ge 8 ] 2>/dev/null; then
    echo "This plugin requires OpenMediaVault 8 or newer (found ${omv_ver}). OMV 7 is end-of-life." >&2
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

echo "==> Installing regctl (regclient) for registry lookups..."
REGCTL_VERSION="v0.11.5"
case "$(uname -m)" in
    x86_64|amd64)  regctl_arch="amd64" ;;
    aarch64|arm64) regctl_arch="arm64" ;;
    *) echo "    Unsupported CPU arch '$(uname -m)'; install regctl manually from https://github.com/regclient/regclient/releases and put 'regctl' on PATH." >&2; regctl_arch="" ;;
esac
if [ -n "${regctl_arch}" ]; then
    regctl_url="https://github.com/regclient/regclient/releases/download/${REGCTL_VERSION}/regctl-linux-${regctl_arch}"
    tmp_regctl="$(mktemp)"
    dl_ok=1
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "${tmp_regctl}" "${regctl_url}" || dl_ok=0
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "${tmp_regctl}" "${regctl_url}" || dl_ok=0
    else
        dl_ok=0; echo "    Neither curl nor wget is available to download regctl." >&2
    fi
    if [ "${dl_ok}" -eq 1 ]; then
        install -D -m 0755 "${tmp_regctl}" /usr/local/bin/regctl
        echo "    regctl installed at /usr/local/bin/regctl (${REGCTL_VERSION})"
    else
        echo "    WARNING: could not download regctl. The checker needs 'regctl' on PATH;" >&2
        echo "    install it manually from the URL above, then re-run this installer." >&2
    fi
    rm -f "${tmp_regctl}"
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
