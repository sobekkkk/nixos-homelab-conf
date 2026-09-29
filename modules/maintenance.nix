{ ... }:

{
  # Les mises à jour restent volontaires : elles sont examinées et testées
  # avant d'être appliquées au système et à la chaîne de démarrage.
  system.autoUpgrade.enable = false;

  # Supprime chaque semaine les générations devenues inutiles après 30 jours.
  nix.gc = {
    automatic = true;
    dates = "Sun *-*-* 03:15:00";
    options = "--delete-older-than 30d";
    persistent = true;
    randomizedDelaySec = "30min";
  };

  # Déduplique le store après la fenêtre du garbage collector.
  nix.optimise = {
    automatic = true;
    dates = [ "Sun *-*-* 04:15:00" ];
    persistent = true;
    randomizedDelaySec = "30min";
  };
}
