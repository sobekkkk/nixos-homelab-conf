{ ... }:

{
  users.users.sobek = {
    isNormalUser = true;
    description = "Sobek";

    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };
}

