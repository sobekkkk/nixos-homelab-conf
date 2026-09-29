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
    # White-box audit tools. They remain ordinary user-space commands and do
    # not grant sobek access to sudo or the Docker socket.
    gitleaks
    nmap
    nuclei
    ssh-audit
    testssl
    trivy
    vulnix
  ];
}

