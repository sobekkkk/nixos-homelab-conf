"""Independent host observer. No automatic repair, no secret in log/arguments."""
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import urllib.request


def notify(message):
    try:
        text = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "discord.conf").read_text()
        match = re.search(r'^\s*DISCORD_WEBHOOK_URL\s*=\s*(.+)$', text, re.M)
        url = shlex.split(match.group(1))[0] if match else ""
        if not re.fullmatch(r"https://discord\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+", url):
            raise ValueError("invalid credential")
        request = urllib.request.Request(url + "?wait=true", data=json.dumps({"content": message, "allowed_mentions": {"parse": []}}).encode(), headers={"Content-Type": "application/json", "User-Agent": "homelab-gateway-monitor/1"})
        # Never follow a redirect carrying the webhook token to another host.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *_):
                return None
        with urllib.request.build_opener(NoRedirect).open(request, timeout=10) as response:
            if response.status not in (200, 204):
                raise ValueError("delivery failed")
        print("Discord delivery accepted")
        return True
    except Exception:
        print("Discord delivery FAILED; credential/DNS/connectivity check required", file=sys.stderr)
        return False


def observe(url):
    failures = []
    for unit in ("privacy-gateway-vm", "tailscale-homepage-serve", "tailscale-netv-serve"):
        if subprocess.run(["systemctl", "is-active", "--quiet", unit + ".service"], timeout=3).returncode:
            failures.append(unit)
    try:
        with urllib.request.build_opener(urllib.request.ProxyHandler({})).open(url, timeout=35) as response:
            report = json.loads(response.read(4096))
        required = ("handshake", "dns", "mullvad_exit", "tailscale")
        failures.extend(name for name in required if report.get("checks", {}).get(name) is not True)
    except Exception:
        failures.append("gateway_health_unreachable")
    return failures


def transition(state, failures, now):
    """Three failures to trigger; two successes to recover; repeat every 30 min."""
    state["bad"] = state.get("bad", 0) + 1 if failures else 0
    state["good"] = 0 if failures else state.get("good", 0) + 1
    event = None
    if failures and state["bad"] >= 3 and (not state.get("incident") or now - state.get("sent", 0) >= 1800):
        event = "CRITICAL: privacy-gateway / relais indisponibles: " + ", ".join(failures) + ". Sortie directe non autorisee; verifier le tunnel et la cle Mullvad."
    elif not failures and state.get("incident") and state["good"] >= 2:
        event = "RECOVERY: privacy-gateway, DNS, sortie Mullvad et relais verifies."
    return event


def main():
    if sys.argv[1] == "--test":
        return 0 if notify("TEST: observateur privacy-gateway sur homelab; ce message ne valide pas les sondes ni les seuils.") else 1
    path = Path(os.environ["STATE_DIRECTORY"]) / "state.json"
    try:
        state = json.loads(path.read_text())
    except (OSError, ValueError):
        state = {}
    failures = observe(sys.argv[1])
    now = time.time()
    event = transition(state, failures, now)
    delivered = True
    if event:
        delivered = notify(event)
        if delivered:
            state["incident"] = bool(failures)
            state["sent"] = now
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(state))
    temp.replace(path)
    print("Checks: " + (", ".join(failures) if failures else "healthy"))
    return 0 if delivered else 1


if __name__ == "__main__":
    sys.exit(main())
