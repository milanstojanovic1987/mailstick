{
  description = "MailStick – reproducible, read-only NixOS ISO for encrypted USB mail appliance (Milestone 2)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # for installing packages inside your NixOS modules
        pkgsFor = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };

        # build the NixOS system (the ISO) via the flake-native entrypoint
        stickSystem = nixpkgs.lib.nixosSystem {
          inherit system;

          # make `pkgsFor` available as `pkgs` inside your modules
          specialArgs = { inherit pkgsFor; };

          modules = [
            ({ config, pkgs, ... }: {
              ##########################
              # 1. arch
              nixpkgs.hostPlatform.system = system;

              # 2. kernel hardening
              boot.kernelParams = [
                "lockdown=confidentiality"
                "randomize_kstack_offset=on"
                "panic_on_oops=1"
              ];

              # 3. first-boot provisioning
              systemd.services.mailstick-init = {
                description     = "MailStick first-boot provisioning (LUKS+FIDO2)";
                wantedBy        = [ "multi-user.target" ];
                serviceConfig   = {
                  Type            = "oneshot";
                  RemainAfterExit = true;
                  ExecStart       = "${pkgs.writeShellScript "init-mailstick" ''
                    set -eu
                    if [ ! -e /persist/INITTED ]; then
                      echo "≫ Creating encrypted persistence on /dev/sdX3 …"
                      cryptsetup luksFormat /dev/sdX3 \
                        --type luks2 --pbkdf argon2id --iter-time 5000
                      systemd-cryptenroll --fido2-device=auto /dev/sdX3
                      mkdir -p /persist/{postfix,tor/hidden_service_mail}
                      touch /persist/INITTED
                    fi
                  ''}";
                };
              };

              # 4. Tor hidden service
              services.tor = {
                enable = true;
                hiddenServices.mail = {
                  version     = 3;
                  storagePath = "/persist/tor/hidden_service_mail";
                  POWDefense  = { enable = true; difficulty = 18; };
                  mappings    = [
                    { target = 25;  source = 2525; }
                    { target = 587; source = 1587; }
                  ];
                };
              };

              # 5. Postfix
              services.postfix = {
                enable = true;
                config = {
                  myhostname      = "mailstick.local";
                  mydestination   = "";
                  home_mailbox    = "Maildir/";
                  inet_interfaces = "localhost";
                  smtpd_banner    = "$myhostname ready (MailStick)";
                };
                masterConfig.extraLines = ''
                  2525 inet n - y - - smtpd
                  1587 inet n - y - - smtpd
                '';
              };

              # 6. Extra packages
              environment.systemPackages = with pkgs; [
                cryptsetup libfido2 tor postfix gnupg vim
              ];

              # 7. User account
              users.users.mailstick = {
                isNormalUser          = true;
                extraGroups           = [ "wheel" ];
                initialHashedPassword = "";  # set later via `passwd`
              };

              # 8. Block audio/video
              boot.blacklistedKernelModules = [ "snd_hda_intel" "uvcvideo" ];

              # 9. Nix settings
              nix.settings = {
                sandbox                     = true;
                extra-experimental-features = [ "nix-command" "flakes" ];
              };
            })
          "${pkgsFor}/nixos/modules/installer/cd-dvd/installation-cd.nix"
          ];
        };
      in
      {
        packages.isoImage = stickSystem.config.system.build.isoImage;
      }
    );
}
