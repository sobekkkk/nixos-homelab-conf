{ lib, ... }:

{
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;

  # Utilise automatiquement le token TPM2 LUKS au démarrage.
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = [
    "tpm2-device=auto"
  ];

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";

    configurationLimit = 4;

    measuredBoot = {
      enable = true;
      pcrs = [
        0
        4
        7
      ];
    };
  };
}
