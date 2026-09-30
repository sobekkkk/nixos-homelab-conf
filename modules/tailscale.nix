{ config, pkgs, ... }:

{
  # Accès d'administration distant privé. Aucun port TCP/UDP Internet n'est
  # publié par cette configuration : Tailscale établit ses connexions sortantes
  # et utilise DERP chiffré lorsqu'un chemin direct n'est pas disponible.
  services.tailscale.enable = true;

  # L'interface ne devient pas globalement fiable : seuls SSH et le relais
  # HTTPS privé de Portainer y sont acceptés.
  networking.firewall.extraInputRules = ''
    iifname "${config.services.tailscale.interfaceName}" tcp dport 22 accept comment "SSH from trusted tailnet"
    iifname "${config.services.tailscale.interfaceName}" tcp dport 443 accept comment "Portainer HTTPS from trusted tailnet"
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
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=443 https+insecure://127.0.0.1:9443";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --https=443 off";
    };
  };
}
