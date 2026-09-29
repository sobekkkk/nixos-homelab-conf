{ config, ... }:

{
  # Accès d'administration distant privé. Aucun port TCP/UDP Internet n'est
  # publié par cette configuration : Tailscale établit ses connexions sortantes
  # et utilise DERP chiffré lorsqu'un chemin direct n'est pas disponible.
  services.tailscale.enable = true;

  networking.firewall.trustedInterfaces = [
    config.services.tailscale.interfaceName
  ];
}
