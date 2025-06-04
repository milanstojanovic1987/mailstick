{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      # Top-level helper; note **nixpkgs.lib**, not pkgs.lib
      base = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    in {
      nixosConfigurations.mailstick-vbox = base;

      packages.${system} = {
        isoImage = base.config.system.build.isoImage;
        vmImage  = base.config.system.build.vmImage;
      };
    };
}
