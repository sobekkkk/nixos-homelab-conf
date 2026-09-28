{ ... }:

{
  networking.nftables.enable = true;

  networking.firewall = {
    enable = true;

    # Aucun port ouvert globalement.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];

    # SSH autorisé uniquement depuis le LAN IPv4.
    extraInputRules = ''
      ip saddr 192.168.1.0/24 tcp dport 22 accept comment "SSH from trusted LAN"
    '';
  };
}
