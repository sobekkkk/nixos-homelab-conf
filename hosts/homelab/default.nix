
{ ... }:

{
  imports = [
    
./hardware-configuration.nix

    ../../modules/base.nix
    ../../modules/boot.nix
    ../../modules/networking.nix
    ../../modules/tailscale.nix
    ../../modules/users.nix
    ../../modules/sudo.nix
    ../../modules/packages.nix
    ../../modules/ssh.nix
    ../../modules/firewall.nix
    ../../modules/hardening.nix
    ../../modules/auditing.nix
    ../../modules/maintenance.nix
    ../../modules/containers.nix
    ../../modules/netv-network.nix
    ../../modules/security-snapshot.nix
  ];


  networking.hostName = "homelab";


  system.stateVersion = "26.05";
}
