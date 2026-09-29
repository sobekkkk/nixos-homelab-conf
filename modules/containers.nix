{ config, lib, pkgs, ... }:

{
  # Docker fournit uniquement le moteur local. Les services applicatifs sont
  # administrés dans Portainer, sans donner le groupe Docker à l'utilisateur.
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    logDriver = "journald";
    daemon.settings = {
      "live-restore" = true;
      "userland-proxy" = false;
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.portainer = {
      image = "portainer/portainer-ce:2.39.0";
      pull = "missing";
      # Migration temporaire : le port direct reste disponible le temps de
      # déployer puis valider Caddy. Il sera retiré dans l'étape suivante.
      ports = [ "9443:9443" ];
      networks = [ "homelab-proxy" ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "portainer_data:/data"
      ];
      extraOptions = [ "--security-opt=no-new-privileges:true" ];
    };
  };

  assertions = [
    {
      assertion = !(lib.elem "docker" (config.users.users.sobek.extraGroups or [ ]));
      message = "sobek must not join the Docker group: Docker socket access is root-equivalent.";
    }
  ];

  # Docker publie ses ports après traduction NAT, ce qui contourne les règles
  # INPUT habituelles. Cette garde protège donc la chaîne DOCKER-USER elle-même.
  # Elle limite tout port publié par Docker au LAN IPv4 et refuse toute arrivée
  # IPv6 sur l'interface réseau actuelle. À adapter si l'interface change.
  systemd.services.docker-lan-guard = {
    description = "Restrict Docker-published ports to the trusted LAN";
    wantedBy = [ "docker.service" ];
    partOf = [ "docker.service" ];
    after = [ "docker.service" ];
    before = [ "docker-portainer.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.iptables ];
    script = ''
      iptables -w -N HOMELAB-DOCKER-GUARD 2>/dev/null || true
      iptables -w -F HOMELAB-DOCKER-GUARD
      iptables -w -A HOMELAB-DOCKER-GUARD -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
      iptables -w -A HOMELAB-DOCKER-GUARD -i wlp0s20f3 ! -s 192.168.1.0/24 -j DROP
      iptables -w -A HOMELAB-DOCKER-GUARD -j RETURN
      iptables -w -C DOCKER-USER -j HOMELAB-DOCKER-GUARD 2>/dev/null || \
        iptables -w -I DOCKER-USER 1 -j HOMELAB-DOCKER-GUARD

      if ip6tables -w -S DOCKER-USER >/dev/null 2>&1; then
        ip6tables -w -N HOMELAB-DOCKER-GUARD 2>/dev/null || true
        ip6tables -w -F HOMELAB-DOCKER-GUARD
        ip6tables -w -A HOMELAB-DOCKER-GUARD -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ip6tables -w -A HOMELAB-DOCKER-GUARD -i wlp0s20f3 -j DROP
        ip6tables -w -A HOMELAB-DOCKER-GUARD -j RETURN
        ip6tables -w -C DOCKER-USER -j HOMELAB-DOCKER-GUARD 2>/dev/null || \
          ip6tables -w -I DOCKER-USER 1 -j HOMELAB-DOCKER-GUARD
      fi
    '';
  };

  # Ce réseau est l'unique lien entre le proxy TLS et les interfaces internes.
  # Il est créé avant Portainer pour que celui-ci ne soit jamais publié sur
  # l'interface hôte.
  systemd.services.docker-homelab-proxy-network = {
    description = "Create the shared Docker network for the HTTPS proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "docker-lan-guard.service" ];
    requires = [ "docker.service" "docker-lan-guard.service" ];
    before = [ "docker-portainer.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ config.virtualisation.docker.package ];
    script = ''
      docker network inspect homelab-proxy >/dev/null 2>&1 || \
        docker network create --driver bridge homelab-proxy
    '';
  };

  # Portainer ne peut démarrer que lorsque la garde et le réseau proxy existent.
  systemd.services.docker-portainer = {
    requires = [ "docker-lan-guard.service" "docker-homelab-proxy-network.service" ];
    after = [ "docker-lan-guard.service" "docker-homelab-proxy-network.service" ];
  };
}
