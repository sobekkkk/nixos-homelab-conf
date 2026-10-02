{ pkgs, ... }:
let
  n = import ../lib/netv-network.nix;
  common = {
    DynamicUser = true;
    User = "privacy-gateway-monitor";
    StateDirectory = "privacy-gateway-monitor";
    StateDirectoryMode = "0700";
    LoadCredential = "discord.conf:/var/lib/homelab-secrets/netdata-discord.conf";
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    TimeoutStartSec = "55s";
    UMask = "0077";
  };
in {
  systemd.services.privacy-gateway-monitor = {
    description = "Independent functional gateway checks and Discord notifications";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.systemd ];
    serviceConfig = common // {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../scripts/privacy-gateway/monitor.py} http://${n.underlayGuest}:9105/health";
    };
  };
  systemd.timers.privacy-gateway-monitor = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnBootSec = "5min"; OnUnitInactiveSec = "30s"; AccuracySec = "1s"; };
  };
  systemd.services.privacy-gateway-monitor-test = {
    description = "Send a synthetic gateway-monitor test to Discord without stopping services";
    serviceConfig = common // {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../scripts/privacy-gateway/monitor.py} --test";
    };
  };
}
