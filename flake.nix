{
  description = "MailStick – reproducible, read-only NixOS ISO for encrypted USB mail appliance (Milestone 2)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = false; };
      in {
        packages.isoImage = pkgs.nixos ({ config, ... }: {
          nixpkgs.hostPlatform.system = system;

          # 1. Immutable root
          boot.enableDMVerity = true;
          boot.dmVerity.mode  = "direct";

          # 2. Hardened kernel flags
          boot.kernelParams = [
            "lockdown=confidentiality"
            "randomize_kstack_offset=on"
            "panic_on_oops=1"
          ];

          # 3. First-boot persistence wizard (LUKS + FIDO2)
          services.mailstick-init = {
            description = "First-boot provisioning (LUKS + FIDO2)";
            wantedBy    = [ "multi-user.target" ];
            script = pkgs.writeShellScript "init-mailstick" ''
              set -eu
              if [ ! -e /persist/INITTED ]; then
                echo "≫ Creating encrypted persistence on /dev/sdX3 …"
                cryptsetup luksFormat /dev/sdX3 \\
                  --type luks2 --pbkdf argon2id --iter-time 5000
                systemd-cryptenroll --fido2-device=auto /dev/sdX3
                mkdir -p /persist/{postfix,dovecot,tor/hidden_service_mail}
                touch /persist/INITTED
              fi
            '';
          };

          # 4a. Tor v3 onion with PoW
          services.tor = {
            enable = true;
            hiddenServices.mail = {
              version     = 3;
              storagePath = "/persist/tor/hidden_service_mail";
              POWDefense = { enable = true; difficulty = 18; };
              mappings = [
                { target = 25;   source = 2525; }
                { target = 143;  source = 1143; }
                { target = 587;  source = 1587; }
              ];
            };
          };

          # 4b. Postfix (SMTP)
          services.postfix = {
            enable  = true;
            dataDir = "/persist/postfix";
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

          # 4c. Dovecot (IMAP)
          services.dovecot2 = {
            enable       = true;
            dataDir      = "/persist/dovecot";
            mailLocation = "maildir:~/Maildir";
            protocols    = [ "imap" ];
            listen       = "127.0.0.1:1143";
            ssl.enable   = false;
            auth.mechanisms = [ "plain" ];
            auth.disablePlaintextAuth = false;
          };

          # 5. Packages
          environment.systemPackages = with pkgs; [
            cryptsetup libfido2 tor postfix dovecot gnupg vim
          ];

          # 6. ISO metadata
          isoImage = {
            volumeID          = "MAILSTICK";
            makeEfiBootable   = true;
            squishfsCompression = "xz";
          };

          # 7. User
          users.users.mailstick = {
            isNormalUser = true;
            extraGroups  = [ "wheel" ];
            initialHashedPassword = "";
          };

          # 8. Disable AV devices
          boot.blacklistedKernelModules = [ "snd_hda_intel" "uvcvideo" ];

          # 9. Nix settings
          nix.settings = {
            sandbox = true;
            extra-experimental-features = [ "nix-command" "flakes" ];
          };
        });
      });
}
