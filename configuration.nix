{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName = "mailstick";
  time.timeZone       = "UTC";

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
      # Persist all Tor state under /persist/tor
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
    # mail queue directory
    "d /var/spool/postfix                       0755 mailuser mailuser -"
    # ensure /persist and Tor data dirs exist on every boot
    "d /persist                                 0755 root     root     -"
    "d /persist/tor                             0700 tor      tor      -"
    "d /persist/tor/hidden_service_mail         0700 tor      tor      -"
  ];

  ###########################
  # Filesystems             #
  ###########################
  fileSystems."/" = {
    device = "/dev/mapper/data";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/boot";
    fsType = "vfat";
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
