{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs = {
    # Official 25.05 channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Tiny helper: flake-utils gives eachSystem, etc.—handy later
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        # This is the piece nixos-rebuild expects
        nixosConfigurations.mailstick-vbox = pkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./configuration.nix ];
        };
      });
}
