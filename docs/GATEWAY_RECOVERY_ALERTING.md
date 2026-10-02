# Gateway recovery and independent alerting — 2026-10-02

## Incident evidence

Host and VM were active. WireGuard's last successful handshake was older than
20 minutes; guest DNS timed out and Tailscale could not reach its control plane
or DERP. Host Netdata exposed 17 `homelab_*` rules, all CLEAR, but none observed
guest tunnel functionality. No evidence establishes censorship as the cause.
An unreachable server, revoked device, expired subscription or blocked path
remain candidates. A past Discord test does not prove incident coverage.

After owner test activation on 2026-10-02, the new peer responded and the guest
reported Mullvad exit `de-fra-wg-001`; Tailscale returned online. DNS resolution
worked, but the initial health unit mistakenly used `pkgs.bind` instead of the
separate `pkgs.dig` output, causing a false `dns` failure. The follow-up fixes
the executable dependency. Startup connection refusals are retried and should
not produce JSON tracebacks. The corrected unit still requires test activation.

## Prepared change (not deployed/validated until owner rotates key)

Secure Salmon public metadata replaces Huge Hare. Host and guest allowlists
change together. Private key stays root-owned 0600 outside Git/Nix. Run the
reviewed `scripts/privacy-gateway/rotate-key-and-test.sh` interactively as root.
It builds before replacing the key, activates TEST only, checks the functional
endpoint and sends a synthetic Discord message. No automatic boot switch.
Do not paste the key in chat, commands, logs or tickets. Previous-generation
rollback alone does not restore the previous key: use the owner's saved profile.

## Independent monitoring path

```text
Host timer (normal ISP uplink) -> Discord
       |
       +-> host VM / Homepage Serve / NetV Serve unit state
       +-> private guest endpoint 172.30.242.2:9105/health
                 +-> WireGuard handshake age <180 s
                 +-> AdGuard DNS resolution
                 +-> HTTPS Mullvad exit verification, IPv4, bound to WireGuard
                 +-> Tailscale Running and Online
```

The guest endpoint returns booleans only, binds its management address and is
allowed solely from the host management bridge address. No public/Tailscale/app
access and no keys, IP results, peer IDs or detailed errors in responses/logs.
The host monitor loads the existing Netdata Discord configuration as a systemd
credential; it never prints it or passes it as a command argument. The parser
accepts only the documented Discord URL variable and never executes shell code.
TLS verification stays enabled; webhook redirects are refused and mentions off.

Three failed checks trigger CRITICAL; two successful checks trigger RECOVERY.
Polling waits 30 s after each run (probe time is additional), boot grace 5 min,
critical reminders 30 min. Discord delivery failures return a failing service
status, stay in the journal and retry without recording successful delivery.
No restart loop, arbitrary server failover or direct-WAN fallback is introduced.

## Limits and validation

The Mullvad verification site is an external dependency; its failure alerts
`mullvad_exit` and does not by itself prove a broken tunnel. A recent handshake
does not by itself prove usable Internet. The endpoint does not validate IPv6,
client throughput, NetV playback or connectivity from every client.

This observer is independent of the VM and Netdata, but shares the host and its
ISP. A host/ISP/Discord outage cannot reliably notify through this path. An
off-host heartbeat watcher is still required for complete outage detection.
No external paid service/account was created implicitly.

Before persisting: receive the synthetic test; verify live checks; verify clients
use Mullvad; repeat the approved VPN-down test with a scheduled restore and
confirm real CRITICAL then RECOVERY. Unit tests validate logic, not delivery.

## Anti-censorship decision

Native WireGuard stays in place for this recovery: changing cryptography, MTU,
port or Keepalive is not equivalent to traffic obfuscation. No unlimited bypass
or anonymity guarantee is made. Mullvad documents QUIC, Shadowsocks, LWO and
UDP-over-TCP through its official app, not the exported WireGuard configuration:
https://mullvad.net/en/help/connecting-to-mullvad-vpn-from-restrictive-locations

A separate reviewed migration to the Mullvad daemon would require runtime
account provisioning, changed route/firewall integration, relay bootstrap rules,
performance comparisons and new fail-closed tests. Do not bolt a generic proxy
onto this gateway or broaden the firewall merely to claim anti-censorship.
