{ config, ... }:

{
  # Accès d'administration distant privé. Aucun port TCP/UDP Internet n'est
  # publié par cette configuration : Tailscale établit ses connexions sortantes
  # et utilise DERP chiffré lorsqu'un chemin direct n'est pas disponible.
  services.tailscale.enable = true;

  # L'interface ne devient pas globalement fiable : seul SSH y est accepté.
  networking.firewall.extraInputRules = ''
    iifname "${config.services.tailscale.interfaceName}" tcp dport 22 accept comment "SSH from trusted tailnet"
  '';
}
