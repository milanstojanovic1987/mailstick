{ config, pkgs, ... }:

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
  # Instead of editing /etc/nix/nix.conf directly (which is read-only at runtime),
  # we expose the same setting through configuration.nix:
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
    "d /var/spool/postfix                       0755 mailuser mailuser -"
  ];

  ###########################
  # Force‐create before Tor  #
  ###########################
  systemd.services."tor.service".serviceConfig = {
    # Don’t start Tor until /persist is mounted:
    Requires = [ "persist.mount" ];
    After    = [ "persist.mount" ];

    # Before Tor’s main ExecStart, create and secure /persist/tor
    ExecStartPre = [
      "/run/current-system/sw/bin/mkdir -p /persist/tor/hidden_service_mail"
      "/run/current-system/sw/bin/chown tor:tor /persist/tor"
      "/run/current-system/sw/bin/chown tor:tor /persist/tor/hidden_service_mail"
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
