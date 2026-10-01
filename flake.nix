{
  description = "Sobek NixOS homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, lanzaboote, ... }: {
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        lanzaboote.nixosModules.lanzaboote
        ./hosts/homelab
        ({ ... }: {
          imports = [ ./modules/privacy-gateway-vm.nix ];
          homelab.privacyGatewayVM.vmPackage =
            self.nixosConfigurations.privacy-gateway.config.system.build.vm;
        })
      ];
    };
    nixosConfigurations.privacy-gateway = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/privacy-gateway
        (nixpkgs + "/nixos/modules/virtualisation/qemu-vm.nix")
      ];
    };
  };
}
