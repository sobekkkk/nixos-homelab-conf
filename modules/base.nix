{ ... }:

{

  time.timeZone = "Europe/Paris";

  i18n.defaultLocale = "fr_FR.UTF-8";

  console.keyMap = "fr";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  security.sudo.wheelNeedsPassword = true;
}
