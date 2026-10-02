# Dedicated guest only. The QEMU module is supplied by the pinned evaluator.
{ lib, pkgs, ... }:
let n = import ../../lib/netv-network.nix; in
{
  imports = [ ./gateway.nix ./mullvad-profile.nix ./health.nix ];
  system.stateVersion = "26.05";
  homelab.privacyGateway = {
    enable = true;
    guestConfirmed = true;
    bootstrapSSHAddress = n.underlayHost;
    underlayInterface = "uplink0";
  };
  systemd.network.links."10-gateway-uplink" = {
    matchConfig.MACAddress = "52:54:00:24:02:02";
    linkConfig.Name = "uplink0";
  };
  systemd.network.links."10-gateway-netv" = {
    matchConfig.MACAddress = "52:54:00:24:00:02";
    linkConfig.Name = "apps0";
  };
  networking.usePredictableInterfaceNames = false;
  # Immutable appliance: rebuild on the host, never maintain a guest Nix DB.
  nix.enable = false;
  virtualisation = {
    memorySize = 2048;
    cores = 2;
    diskSize = 8192;
    diskImage = "/var/lib/privacy-gateway-vm/gateway.qcow2";
    graphics = false;
    mountHostNixStore = false;
    useNixStoreImage = true;
    writableStore = false;
    sharedDirectories = lib.mkForce { };
    forwardPorts = lib.mkForce [ ];
    qemu.networkingOptions = lib.mkForce [
      "-netdev tap,id=uplink,ifname=${n.underlayTap},script=no,downscript=no"
      "-device virtio-net-pci,netdev=uplink,mac=52:54:00:24:02:02"
      "-netdev tap,id=netv,ifname=${n.egressTap},script=no,downscript=no"
      "-device virtio-net-pci,netdev=netv,mac=52:54:00:24:00:02"
    ];
    qemu.options = [
      "-enable-kvm"
      "-qmp unix:/var/lib/privacy-gateway-vm/qmp.sock,server=on,wait=off"
      "-virtfs local,path=/run/credentials/privacy-gateway-vm.service,security_model=none,readonly=on,mount_tag=wg-secret"
    ];
  };
  # qemu-vm overrides fileSystems; use an explicit mount unit instead.
  systemd.mounts = [ {
    what = "wg-secret";
    where = "/run/mullvad-bootstrap";
    type = "9p";
    options = "trans=virtio,version=9p2000.L,ro,nosuid,nodev,noexec";
    wantedBy = [ "local-fs.target" ];
    before = [ "privacy-gateway-key.service" ];
  } ];
  systemd.services.privacy-gateway-key = {
    description = "Provision the runtime WireGuard key from the read-only credential mount";
    requiredBy = [ "wg-quick-wg-mullvad.service" ];
    before = [ "wg-quick-wg-mullvad.service" ];
    requires = [ "run-mullvad\\x2dbootstrap.mount" ];
    after = [ "run-mullvad\\x2dbootstrap.mount" "systemd-tmpfiles-setup.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; UMask = "0077"; };
    script = ''
      ${pkgs.coreutils}/bin/install -o root -g root -m 0600 \
        /run/mullvad-bootstrap/mullvad-private-key \
        /var/lib/privacy-gateway-secrets/mullvad-private-key
    '';
  };
  users.users.gateway-admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZkSA80pEthN/oaY87sqwDssE5aTAtTl6XGMBNMVa/8 drago@MSI"
    ];
  };
  # Key-only administrator of this guest; no host sudo policy is changed.
  security.sudo.wheelNeedsPassword = false;
  services.openssh.settings.AllowUsers = [ "gateway-admin" ];
  systemd.services.privacy-gateway-identity = {
    description = "Publish only the guest's public SSH fingerprint on its console";
    wantedBy = [ "multi-user.target" ];
    requires = [ "sshd-keygen.service" ];
    after = [ "sshd-keygen.service" ];
    serviceConfig = {
      Type = "oneshot";
      StandardOutput = "journal+console";
      ExecStart = "${pkgs.openssh}/bin/ssh-keygen -l -E sha256 -f /etc/ssh/ssh_host_ed25519_key.pub";
    };
  };
  environment.systemPackages = [ pkgs.curl ];
}
