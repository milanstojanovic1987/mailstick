{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.mailstick-vbox = nixpkgs.lib.nixosSystem {
        inherit system;
        # <- hand the pinned nixpkgs path to the module system
        specialArgs = { inherit nixpkgs; };
        modules = [ ./configuration.nix ];
      };

      packages.${system} = {
        isoImage = self.nixosConfigurations.mailstick-vbox
          .config.system.build.isoImage;

        vmImage = self.nixosConfigurations.mailstick-vbox
          .config.system.build.vmImage;
      };
    };
}
