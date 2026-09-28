
{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./modules/base.nix
    ./modules/packages.nix
    ./modules/ssh.nix
    ./modules/firewall.nix
    ./modules/hardening.nix
    ./modules/networking.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.sobek = {
    isNormalUser = true;
    description = "Sobek";

    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  # Version initiale de l'installation NixOS.
  # Ne pas modifier lors des upgrades.
  system.stateVersion = "26.05";
}

