{ config, pkgs, lib, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName   = "mailstick";
  time.timeZone         = "UTC";

  ###########################
  # Enable Nix Flakes       #
  ###########################
  # This sets the same flag you would otherwise put in /etc/nix/nix.conf,
  # enabling both nix-command and flakes. It is safe to leave here even
  # if you switch back to a non-flake workflow later.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  ########################################
  # Encrypted data partition (LUKS root) #
  ########################################
  boot.initrd.luks.devices = {
    data = {
      device = "/dev/disk/by-partlabel/DATA";
      preLVM = true;
    };
  };

  #################################
  # Disable GRUB → use systemd-boot
  #################################
  boot.loader.grub.enable                = false;
  boot.loader.grub.efiInstallAsRemovable = false;
  boot.loader.systemd-boot.enable        = true;
  boot.loader.efi.canTouchEfiVariables   = true;

  ###########################
  # Tor onion mail relay    #
  ###########################
  services.tor = {
    enable = true;
    settings = {
      DataDirectory        = "/persist/tor";
      HiddenServiceDir     = "/persist/tor/hidden_service_mail";
      HiddenServiceVersion = 3;
      HiddenServicePort    = [
        "25  127.0.0.1:2525"
        "587 127.0.0.1:1587"
      ];
    };
    # We are *not* using `preStart` here, because the Tor module does
    # not support a `preStart` attribute. Instead, we override the
    # systemd unit directly below in `systemd.services."tor.service".serviceConfig`.
  };

  ###########################
  # Postfix & mail user     #
  ###########################
  users.groups.mailuser = { };
  users.users.mailuser = {
    isSystemUser = true;
    group        = "mailuser";
    home         = "/var/lib/mail";
    shell        = "/run/current-system/sw/bin/nologin";
  };

  ###########################
  # Temporary files & dirs  #
  ###########################
  systemd.tmpfiles.rules = [
    # Ensure /var/spool/postfix exists:
    "d /var/spool/postfix                       0755 mailuser mailuser -"
  ];

  ###########################
  # Force‐create before Tor  #
  ###########################
  # This override ensures Tor’s unit waits for /persist, then runs all
  # the `mkdir`, `chown`, and `chmod` commands before starting the Tor daemon.
  systemd.services."tor.service".serviceConfig = {
    # Tor must not start until /persist is mounted:
    Requires = [ "persist.mount" ];
    After    = [ "persist.mount" ];

    # Before Tor’s main ExecStart, create & secure /persist/tor
    ExecStartPre = [
      # Create the hidden‐service folder
      "/run/current-system/sw/bin/mkdir -p /persist/tor/hidden_service_mail"
      # Change ownership so Tor can write there
      "/run/current-system/sw/bin/chown tor:tor /persist/tor"
      "/run/current-system/sw/bin/chown tor:tor /persist/tor/hidden_service_mail"
      # Restrict permissions to 0700 (owner read/write/execute only)
      "/run/current-system/sw/bin/chmod 0700 /persist/tor"
      "/run/current-system/sw/bin/chmod 0700 /persist/tor/hidden_service_mail"
    ];
  };

  ###########################
  # Filesystems             #
  ###########################
  fileSystems."/" = {
    device = "/dev/mapper/data";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };
  fileSystems."/persist" = {
    device = "/dev/disk/by-partlabel/PERSIST";
    fsType  = "ext4";
  };

  ###########################
  # Extras                  #
  ###########################
  environment.systemPackages = with pkgs; [
    alpine
    mutt
    gnupg
  ];
}
