{
  description = "MailStick USB-bootable NixOS ISO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      # Build the NixOS system from configuration.nix
      mailstickSys = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };
    in {
      # Expose the full NixOS configuration
      nixosConfigurations = {
        "${system}" = mailstickSys;
      };

      # Expose the ISO builder for this configuration
      packages.${system}.isoImage = mailstickSys.config.system.build.isoImage;
    };
}
