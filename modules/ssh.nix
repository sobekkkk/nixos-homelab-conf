{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.sobek.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZkSA80pEthN/oaY87sqwDssE5aTAtTl6XGMBNMVa/8 drago@MSI"
  ];
}
