{
  description = "MailStick – reproducible, read-only NixOS ISO for encrypted USB mail appliance (Milestone 2)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };

        stickSystem = pkgs.nixosSystem {
          system = system;
          modules = [
            ({ config, pkgs, ... }: {
              # 1. Tell nixpkgs which arch we’re on
              nixpkgs.hostPlatform.system = system;

              # 2. Kernel hardening
              boot.kernelParams = [
                "lockdown=confidentiality"
                "randomize_kstack_offset=on"
                "panic_on_oops=1"
              ];

              # 3. First-boot provisioning (LUKS + FIDO2)
              systemd.services.mailstick-init = {
                description = "MailStick first-boot provisioning (LUKS+FIDO2)";
                wantedBy    = [ "multi-user.target" ];
                serviceConfig = {
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

              # 4. Tor v3 hidden service + PoW
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

              # 5. Postfix (SMTP only)
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
                initialHashedPassword = "";
              };

              # 8. Block audio/video
              boot.blacklistedKernelModules = [ "snd_hda_intel" "uvcvideo" ];

              # 9. Nix settings
              nix.settings = {
                sandbox                         = true;
                extra-experimental-features     = [ "nix-command" "flakes" ];
              };
            })
          ];
        };
      in {
        packages.isoImage = stickSystem.config.system.build.isoImage;
      }
    );
}
