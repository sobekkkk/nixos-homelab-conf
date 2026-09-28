{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      # Authentification
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;

      # Réduction de la surface d'attaque
      X11Forwarding = false;
      AllowAgentForwarding = false;
      PermitUserEnvironment = false;
      PermitTunnel = false;

      # Anti brute-force basique
      MaxAuthTries = 3;
      LoginGraceTime = 30;

      # Sessions mortes
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      # Journalisation plus détaillée des connexions
      LogLevel = "VERBOSE";

      # Seul le compte administrateur est autorisé
      AllowUsers = [ "sobek" ];
    };
  };

  users.users.sobek.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZkSA80pEthN/oaY87sqwDssE5aTAtTl6XGMBNMVa/8 drago@MSI"
  ];
}
