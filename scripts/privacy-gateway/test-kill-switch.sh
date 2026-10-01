#!/usr/bin/env bash
# Run only INSIDE privacy-gateway. The host's Tailscale is never stopped.
set -euo pipefail
test "$(hostname)" = privacy-gateway
curl -4 -fsS --max-time 10 https://example.com -o /dev/null
curl -6 -fsS --max-time 10 https://example.com -o /dev/null
restore_vpn() { sudo -n systemctl start wg-quick-wg-mullvad.service; }
trap restore_vpn EXIT
sudo -n systemctl stop wg-quick-wg-mullvad.service
check_blocked() {
    local family=$1 address=$2 code=0
    curl "$family" -fsS --connect-timeout 3 --max-time 5 \
        --resolve "example.com:443:$address" https://example.com -o /dev/null || code=$?
    case "$code" in
        7|28) printf 'PASS: VPN-down %s TCP blocked (curl %s)\n' "$family" "$code" ;;
        *) printf 'FAIL: unexpected %s result: %s\n' "$family" "$code" >&2; return 1 ;;
    esac
}
check_blocked -4 104.20.23.154
check_blocked -6 '[2606:4700:10::6814:179a]'
dns_code=0
dig +time=2 +tries=1 @10.64.0.1 example.com >/dev/null 2>&1 || dns_code=$?
test "$dns_code" = 9 || { echo 'FAIL: DNS probe did not time out as expected.' >&2; exit 1; }
echo 'PASS: VPN-down direct upstream DNS blocked'
restore_vpn
trap - EXIT
curl -4 -fsS --retry 2 --max-time 10 https://am.i.mullvad.net/json
printf '\nPASS: tunnel restored; verify mullvad_exit_ip in response.\n'
