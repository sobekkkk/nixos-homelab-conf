
{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./modules/base.nix
    ./modules/boot.nix
    ./modules/packages.nix
    ./modules/ssh.nix
    ./modules/firewall.nix
    ./modules/hardening.nix
    ./modules/networking.nix
    ./modules/users.nix


  ];


  # Version initiale de l'installation NixOS.
  # Ne pas modifier lors des upgrades.
  system.stateVersion = "26.05";
}

