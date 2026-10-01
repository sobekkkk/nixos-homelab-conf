#!/usr/bin/env bash
# Run manually with sudo from the reviewed staging checkout, never Codex sudo.
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Run this reviewed script with sudo.' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test -f "$repo/modules/netv-network.nix"
test -z "$(git -c safe.directory="$repo" -C "$repo" status --porcelain --untracked-files=normal)" || {
  echo 'Checkout must be clean; refusing mixed configuration.' >&2; exit 1;
}
previous=$(readlink -f /run/current-system)
test -x "$previous/bin/switch-to-configuration"
rollback() {
  echo 'Local validation failed; restoring previous running generation.' >&2
  "$previous/bin/switch-to-configuration" test
}
trap rollback ERR
nixos-rebuild test --flake "$repo#homelab"
systemctl is-active --quiet netv-private-network.service
systemctl is-active --quiet privacy-gateway-vm.service
systemctl is-active --quiet privacy-gateway-bootstrap-relay.service
ip -4 rule show | grep -q '^4900:.*from 172.30.240.10 lookup 203$'
ip -4 route show table 203 | grep -q '^default via 172.30.240.2 dev br-netve'
ready=false
for attempt in $(seq 1 60); do
  if timeout 2 bash -c 'exec 3<>/dev/tcp/172.30.242.2/22'; then ready=true; break; fi
  sleep 2
done
test "$ready" = true
trap - ERR
printf 'Test active. Previous generation: %s\n' "$previous"
echo 'No boot switch performed. Verify guest VPN and fail-closed app routing before persisting.'
