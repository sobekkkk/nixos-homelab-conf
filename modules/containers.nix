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
      # Le proxy utilisateur Docker reste nécessaire aux publications de
      # boucle locale. Kuma est explicitement lié à 127.0.0.1:3001 : ce
      # réglage ne lui ouvre aucune interface réseau supplémentaire.
      "userland-proxy" = true;
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.portainer = {
      # Tag lisible + digest du manifeste multi-architecture vérifié le
      # 2026-09-29 auprès du registre Docker Hub. Le digest rend le pull
      # immuable ; sa mise à jour est une revue de changement explicite.
      image = "portainer/portainer-ce:2.39.0@sha256:3267f1869e0fa87b843c55f7fd848f9e3001367d053505f4cb8c664e4a997996";
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
  # IPv6 externe. Les interfaces des bridges Docker et la boucle locale restent
  # autorisées pour ne pas casser les flux internes (dont Caddy -> Portainer).
  # La règle ne dépend donc pas du nom de l'interface physique de l'hôte.
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
      iptables -w -A HOMELAB-DOCKER-GUARD -i lo -j RETURN
      iptables -w -A HOMELAB-DOCKER-GUARD -i docker0 -j RETURN
      iptables -w -A HOMELAB-DOCKER-GUARD -i br-+ -j RETURN
      iptables -w -A HOMELAB-DOCKER-GUARD -s 192.168.1.0/24 -j RETURN
      iptables -w -A HOMELAB-DOCKER-GUARD -j DROP
      iptables -w -C DOCKER-USER -j HOMELAB-DOCKER-GUARD 2>/dev/null || \
        iptables -w -I DOCKER-USER 1 -j HOMELAB-DOCKER-GUARD

      if ip6tables -w -S DOCKER-USER >/dev/null 2>&1; then
        ip6tables -w -N HOMELAB-DOCKER-GUARD 2>/dev/null || true
        ip6tables -w -F HOMELAB-DOCKER-GUARD
        ip6tables -w -A HOMELAB-DOCKER-GUARD -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ip6tables -w -A HOMELAB-DOCKER-GUARD -i lo -j RETURN
        ip6tables -w -A HOMELAB-DOCKER-GUARD -i docker0 -j RETURN
        ip6tables -w -A HOMELAB-DOCKER-GUARD -i br-+ -j RETURN
        ip6tables -w -A HOMELAB-DOCKER-GUARD -j DROP
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
