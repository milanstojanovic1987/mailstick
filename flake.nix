{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs   = import nixpkgs { inherit system; };
      base   = pkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    in {
      # For nixos-rebuild
      nixosConfigurations.mailstick-vbox = base;

      # Ready-to-build images
      packages.${system} = {
        isoImage = base.config.system.build.isoImage;
        vmImage  = base.config.system.build.vmImage;   # raw+qcow2 inside
      };
    };
}
