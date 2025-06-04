{
  description = "MailStick hardened Tor relay (NixOS 25.05)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";

      # --- 1. Running VM / USB config (what you use now) -----------------
      vmConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs; };
        modules     = [ ./configuration.nix ];
      };

      # --- 2. Installer ISO ------------------------------------------------
      isoConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit nixpkgs; };
        modules = [
          ./configuration.nix
          # Adds the bootable ISO builder
          "${nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
        ];
      };
    in
    {
      # For nixos-rebuild
      nixosConfigurations.mailstick-vbox = vmConfig;

      packages.${system} = {
        # Bootable ISO (EFI + BIOS)
        mailstick-iso = isoConfig.config.system.build.isoImage;
      };
    };
}
