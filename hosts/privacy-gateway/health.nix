{ pkgs, ... }:
let n = import ../../lib/netv-network.nix; in {
  # This management endpoint is never allowed from apps0, Tailscale or WAN.
  networking.nftables.tables."privacy-gateway".content = ''
    chain gateway_health_input {
      type filter hook input priority -10; policy accept;
      tcp dport 9105 ip saddr != ${n.underlayHost} drop
      tcp dport 9105 iifname != "uplink0" drop
    }
  '';
  systemd.services.privacy-gateway-health = {
    description = "Secret-free functional VPN health endpoint for the host";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "nftables.service" ];
    requires = [ "nftables.service" ];
    path = [ pkgs.wireguard-tools pkgs.curl pkgs.tailscale pkgs.dig ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/privacy-gateway/health.py} ${n.underlayGuest} ${n.underlayHost}";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
      MemoryMax = "128M";
      TasksMax = 32;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };
}
