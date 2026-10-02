#!/usr/bin/env bash
# Owner-operated after explicit approval. Never run by Codex with sudo.
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Run the reviewed script with sudo.' >&2; exit 1; }
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
test -z "$(git -c safe.directory="$repo" -C "$repo" status --porcelain)" || {
  echo 'Refusing activation of a dirty checkout.' >&2; exit 1;
}
# Resolve the parser from the pinned flake before any activation. Do not
# assume Python or jq is installed in sudo's PATH. jq is already in the
# existing network/Serve service closure; no global package installation.
for command in nix nixos-rebuild docker curl systemctl ip grep; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done
jq_store=$(nix eval --raw "$repo#nixosConfigurations.homelab.pkgs.jq.outPath")
jq_bin="$jq_store/bin/jq"
test -x "$jq_bin" || { echo 'Pinned jq is unavailable; no configuration changed.' >&2; exit 1; }
printf '%s' '{"ok":true}' | "$jq_bin" -e '.ok == true' >/dev/null
for service in dispatcharr worker jellyfin; do
  test -z "$(docker ps --filter "label=com.docker.compose.service=$service" --format '{{.ID}}')" || {
    echo "Stop the new media stack before testing infrastructure: $service is running." >&2; exit 1;
  }
done
previous=$(readlink -f /run/current-system)
test -x "$previous/bin/switch-to-configuration"
rollback() {
  echo 'Validation failed; restoring the previous running generation.' >&2
  "$previous/bin/switch-to-configuration" test
}
trap rollback ERR
nixos-rebuild test --flake "$repo#homelab"
systemctl is-active --quiet netv-private-network.service privacy-gateway-vm.service
for pair in '4900 172.30.240.10' '4901 172.30.240.11' '4902 172.30.240.12' '4903 172.30.240.13'; do
  read -r priority address <<< "$pair"
  ip -4 rule show | grep -q "^$priority:.*from $address lookup 203$"
done
ip -4 route show table 203 | grep -q '^default via 172.30.240.2 dev br-netve'
docker network inspect media-ingress --format '{{.Internal}}' | grep -qx true
healthy=false
for attempt in $(seq 1 90); do
  response=$(curl -fsS --connect-timeout 2 --max-time 8 http://172.30.242.2:9105/health 2>/dev/null || true)
  if printf '%s' "$response" | "$jq_bin" -e '.ok == true' >/dev/null 2>&1; then
    healthy=true; break
  fi
  sleep 2
done
test "$healthy" = true
trap - ERR
printf 'Test active; previous generation for rollback: %s\n' "$previous"
echo 'No boot switch performed. Deploy media only after this test and the reviewed app diff are approved.'
echo 'Provider playback, application VPN-down and client tests remain mandatory before persisting.'
