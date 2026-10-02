#!/usr/bin/env bash
# Interactive owner-only rotation. Never run this through an agent or log the key.
set -euo pipefail
set +x
test "$(id -u)" = 0 || { echo 'Run this reviewed script with sudo.' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
secret_dir=/var/lib/privacy-gateway-secrets
secret_file=/var/lib/privacy-gateway-secrets/mullvad-private-key
test ! -L "$secret_dir"
test ! -L "$secret_file"
install -d -o root -g root -m 0700 "$secret_dir"
# Build first: a failed build must not replace the currently installed key.
nix build "$repo#nixosConfigurations.homelab.config.system.build.toplevel" --no-link
python_bin="$(nix eval --raw "$repo#nixosConfigurations.homelab.pkgs.python3.outPath")/bin/python3"
read -r -s -p 'Paste ONLY the Secure Salmon PrivateKey (hidden), then Enter: ' gateway_key </dev/tty
printf '\n' >/dev/tty
if [[ ! "$gateway_key" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
    unset gateway_key
    echo 'Invalid format; current key unchanged.' >&2
    exit 1
fi
temp_key=$(mktemp /var/lib/privacy-gateway-secrets/.key.XXXXXXXX)
trap 'unset gateway_key; rm -f -- "$temp_key"' EXIT
chmod 0600 "$temp_key"
printf '%s\n' "$gateway_key" > "$temp_key"
unset gateway_key
mv -T -- "$temp_key" "$secret_file"
echo 'Key rotated atomically, outside Git and the Nix store.'
nixos-rebuild test --flake "$repo#homelab"
# The VM credential copy refreshes when the new VM derivation restarts.
systemctl is-active --quiet privacy-gateway-vm.service
ready=false
for attempt in $(seq 1 12); do
    if curl -fsS --max-time 35 http://172.30.242.2:9105/health | \
        "$python_bin" -c '
import json,sys
try:
    healthy = json.load(sys.stdin).get("ok") is True
except (ValueError, AttributeError):
    healthy = False
sys.exit(0 if healthy else 1)
'; then
        ready=true
        break
    fi
    sleep 2
done
if test "$ready" != true; then
    echo 'Functional check failed. No boot switch performed; fail-closed rules remain. Notify the operator.' >&2
    exit 1
fi
systemctl start privacy-gateway-monitor-test.service
echo 'Functional checks passed; Discord accepted the test. Confirm receipt before persisting with switch.'
echo 'Only test activation performed. A rollback to the old VPN profile also needs its original private key.'
