{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs = {
    # Pin to the official 25.05 channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    {
      # <-- nixos-rebuild expects this exact attr path
      nixosConfigurations.mailstick-vbox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./configuration.nix ];
      };
    };
}
