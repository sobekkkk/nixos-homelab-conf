{ config, pkgs, ... }:
let
  # Every Serve writer uses the same lock: concurrent read-modify-write
  # requests otherwise lose the ETag race at boot or during activation.
  serve = pkgs.writeShellScript "private-tailscale-serve" ''
    set -eu
    export PATH=${pkgs.coreutils}/bin
    if [ "$1" = --bg ]; then
      ready=false
      for attempt in $(seq 1 30); do
        if ${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
          ready=true; break
        fi
        sleep 2
      done
      [ "$ready" = true ] || { echo 'Tailscale is not Running; Serve not changed' >&2; exit 1; }
    fi
    exec 9>/run/lock/homelab-tailscale-serve.lock
    ${pkgs.util-linux}/bin/flock -w 30 9
    for attempt in $(seq 1 5); do
      if timeout 10 ${pkgs.tailscale}/bin/tailscale serve "$@"; then exit 0; fi
      sleep 2
    done
    exit 1
  '';
in
{
  # Accès d'administration distant privé. Aucun port TCP/UDP Internet n'est
  # publié par cette configuration : Tailscale établit ses connexions sortantes
  # et utilise DERP chiffré lorsqu'un chemin direct n'est pas disponible.
  services.tailscale.enable = true;

  # Le relais local Kuma utilise le nom Caddy existant : ce mapping statique
  # évite toute dépendance au DNS du routeur et fournit le bon SNI TLS.
  networking.extraHosts = ''
    192.168.1.69 status.home.arpa
    192.168.1.69 netdata.home.arpa
    192.168.1.69 homepage.home.arpa
    192.168.1.69 netv.home.arpa
    192.168.1.69 jellyfin.home.arpa
    192.168.1.69 dispatcharr.home.arpa
  '';

  # L'interface ne devient pas globalement fiable : seuls SSH et les relais
  # HTTPS privés d'administration y sont acceptés.
  networking.firewall.extraInputRules = ''
    iifname "${config.services.tailscale.interfaceName}" tcp dport 22 accept comment "SSH from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 443 accept comment "Portainer HTTPS from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 8443 accept comment "Uptime Kuma HTTPS from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 8444 accept comment "Netdata HTTPS from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 8445 accept comment "Homepage HTTPS from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 8446 accept comment "NetV HTTPS from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport { 8447, 8448 } accept comment "Private media interfaces from tailnet"
  '';

  # Tailscale termine HTTPS avec le certificat du tailnet, puis relaie
  # localement vers le certificat initial auto-signé de Portainer. Ce service
  # reste privé au tailnet : il n'utilise ni Funnel, ni port de routeur.
  systemd.services.tailscale-portainer-serve = {
    description = "Publish Portainer privately through Tailscale Serve";
    requires = [ "tailscaled.service" "docker-portainer.service" ];
    after = [ "tailscaled.service" "docker-portainer.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 180;
      ExecStart = "${serve} --bg --https=443 https+insecure://127.0.0.1:9443";
      ExecStop = "${serve} --https=443 off";
    };
  };

  # Caddy est l'unique point d'entrée de Kuma. Tailscale Serve le joint avec
  # son nom local afin de présenter le bon SNI et sélectionner son vhost.
  systemd.services.tailscale-uptime-kuma-serve = {
    description = "Publish Uptime Kuma privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 180;
      ExecStart = "${serve} --bg --https=8443 https+insecure://status.home.arpa:443";
      ExecStop = "${serve} --https=8443 off";
    };
  };

  # Netdata reste une interface technique privée. Caddy possède un listener
  # LAN dédié à ce relais : le Host du client tailnet ne peut ainsi pas être
  # confondu avec le vhost Kuma, qui utilise Caddy sur 443.
  systemd.services.tailscale-netdata-serve = {
    description = "Publish Netdata privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 180;
      ExecStart = "${serve} --bg --https=8444 https+insecure://netdata.home.arpa:8444";
      ExecStop = "${serve} --https=8444 off";
    };
  };
  # Port dédié : le Host du client ne doit pas sélectionner le vhost Kuma.
  systemd.services.tailscale-homepage-serve = {
    description = "Publish Homepage privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 180;
      ExecStart = "${serve} --bg --https=8445 https+insecure://homepage.home.arpa:8445";
      ExecStop = "${serve} --https=8445 off";
    };
  };
  systemd.services.tailscale-netv-serve = {
    description = "Publish NetV privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 180;
      ExecStart = "${serve} --bg --https=8446 https+insecure://netv.home.arpa:8446";
      ExecStop = "${serve} --https=8446 off";
    };
  };
  systemd.services.tailscale-jellyfin-serve = {
    description = "Publish Jellyfin privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 210;
      ExecStart = "${serve} --bg --https=8447 https+insecure://jellyfin.home.arpa:8447";
      ExecStop = "${serve} --https=8447 off";
    };
  };
  systemd.services.tailscale-dispatcharr-serve = {
    description = "Publish Dispatcharr privately through Tailscale Serve";
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 210;
      ExecStart = "${serve} --bg --https=8448 https+insecure://dispatcharr.home.arpa:8448";
      ExecStop = "${serve} --https=8448 off";
    };
  };
}
