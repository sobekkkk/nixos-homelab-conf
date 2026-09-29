{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    sbctl
    git
    vim
    wget
    curl
    htop
    tree
  ];
}

