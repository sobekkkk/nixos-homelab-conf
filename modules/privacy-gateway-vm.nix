# Host integration: import only after setting vmPackage to the built VM store path.
{ config, lib, pkgs, ... }:
let cfg = config.homelab.privacyGatewayVM; in
{
  options.homelab.privacyGatewayVM.vmPackage = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = "Built pinned QEMU VM package, never a shell command or mutable checkout.";
  };
  config = lib.mkIf (cfg.vmPackage != null) {
    users.groups.privacy-gateway-vm = { };
    users.users.privacy-gateway-vm = {
      isSystemUser = true;
      group = "privacy-gateway-vm";
      extraGroups = [ "kvm" ];
    };
    systemd.services.privacy-gateway-vm = {
      description = "Isolated Mullvad, AdGuard and Tailscale gateway VM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        User = "privacy-gateway-vm";
        Group = "privacy-gateway-vm";
        StateDirectory = "privacy-gateway-vm";
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/privacy-gateway-vm";
        LoadCredential = "mullvad-private-key:/var/lib/privacy-gateway-secrets/mullvad-private-key";
        ExecStart = "${cfg.vmPackage}/bin/run-privacy-gateway-vm";
        ExecStop = pkgs.writeScript "privacy-gateway-powerdown" ''
          #!${pkgs.python3}/bin/python3
          import json, os, socket, time
          try:
              with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
                  client.settimeout(3)
                  client.connect('/var/lib/privacy-gateway-vm/qmp.sock')
                  stream = client.makefile('rwb', buffering=0)
                  stream.readline()
                  for command in ('qmp_capabilities', 'system_powerdown'):
                      stream.write((json.dumps({'execute': command}) + '\n').encode())
                      while True:
                          response = json.loads(stream.readline())
                          if 'return' in response or 'error' in response:
                              break
              for _ in range(80):
                  if not os.path.exists('/var/lib/privacy-gateway-vm/qmp.sock'):
                      break
                  time.sleep(1)
          except (OSError, ValueError):
              pass
        '';
        Restart = "on-failure";
        RestartSec = "15s";
        TimeoutStopSec = "90s";
        KillSignal = "SIGTERM";
        UMask = "0077";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        DevicePolicy = "closed";
        DeviceAllow = [ "/dev/kvm rw" ];
      };
    };
    # Override only inside this Match stanza, not the global SSH policy.
    services.openssh.extraConfig = ''
      Match User sobek
        AllowTcpForwarding local
        PermitOpen 127.0.0.1:2222
      Match all
    '';
  };
}
