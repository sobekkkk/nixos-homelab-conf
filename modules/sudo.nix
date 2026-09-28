{ ... }:

{
  security.pam.services.su.requireWheel = true;

  security.sudo = {
    enable = true;

    # Les membres de wheel doivent saisir leur mot de passe.
    wheelNeedsPassword = true;

    # Seuls les membres de wheel peuvent exécuter le wrapper sudo.
    execWheelOnly = true;

    # Ne permet pas la conservation arbitraire de variables
    # d'environnement lors d'une élévation de privilèges.
    defaultOptions = [
      "NOSETENV"
    ];

    extraConfig = ''
      Defaults use_pty
    '';
  };
}
