{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName = "mailstick";
  time.timeZone         = "UTC";

  ########################################
  # Encrypted data partition (LUKS root) #
  ########################################
  boot.initrd.luks.devices = {
    data = {
      device  = "/dev/disk/by-partuuid/1234-ABCD";
      preLVM  = true;
    };
  };

  #################################
  # Disable GRUB → use systemd-boot
  #################################
  boot.loader.grub.enable                 = false;
  boot.loader.grub.efiInstallAsRemovable  = false;
  boot.loader.systemd-boot.enable         = true;
  boot.loader.efi.canTouchEfiVariables    = true;

  ###########################
  # Tor onion mail relay    #
  ###########################
  services.tor = {
    enable   = true;
    settings = {
      HiddenServiceDir     = "/persist/tor/hidden_service_mail";
      HiddenServiceVersion = 3;
      HiddenServicePort    = [
        "25 127.0.0.1:2525"
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
  systemd.tmpfiles.rules = [
    "d /var/spool/postfix 0755 mailuser mailuser -"
  ];

  ###########################
  # Filesystems             #
  ###########################
  fileSystems."/" = {
    device = "/dev/mapper/data";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    # we’re using the parted partition label “boot”
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
