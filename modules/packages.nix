{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    sbctl
    git
    codex
    vim
    wget
    curl
    htop
    tree
    iptables
  ];
}

