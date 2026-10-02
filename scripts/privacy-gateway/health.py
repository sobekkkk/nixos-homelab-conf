"""Report booleans only: never expose addresses, keys, peer IDs or raw errors."""
import http.server
import json
import subprocess
import sys
import time


def run(*args):
    return subprocess.check_output(args, timeout=10, stderr=subprocess.DEVNULL, text=True)


def health():
    checks = {}
    try:
        values = [int(line.split()[1]) for line in run("wg", "show", "wg-mullvad", "latest-handshakes").splitlines()]
        checks["handshake"] = bool(values) and all(0 < time.time() - value < 180 for value in values)
    except Exception:
        checks["handshake"] = False
    try:
        answer = run("dig", "@127.0.0.1", "am.i.mullvad.net", "+short", "+time=2", "+tries=1")
        checks["dns"] = bool(answer.strip())
    except Exception:
        checks["dns"] = False
    try:
        result = json.loads(run("curl", "--interface", "wg-mullvad", "-4fsS", "--max-time", "8", "https://am.i.mullvad.net/json"))
        checks["mullvad_exit"] = result.get("mullvad_exit_ip") is True
    except Exception:
        checks["mullvad_exit"] = False
    try:
        status = json.loads(run("tailscale", "status", "--json"))
        checks["tailscale"] = status.get("BackendState") == "Running" and status.get("Self", {}).get("Online") is True
    except Exception:
        checks["tailscale"] = False
    return checks


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.client_address[0] != sys.argv[2] or self.path != "/health":
            self.send_error(404)
            return
        checks = health()
        body = json.dumps({"ok": all(checks.values()), "checks": checks}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    http.server.HTTPServer((sys.argv[1], 9105), Handler).serve_forever()
