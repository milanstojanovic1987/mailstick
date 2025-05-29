{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName   = "mailstick";
  time.timeZone         = "UTC";

  ########################################
  # Encrypted data partition (LUKS root) #
  ########################################
  boot.initrd.luks.devices = {
    data = {
      device = "/dev/disk/by-label/DATA";
      preLVM = true;
    };
  };

  ###########################
  # Tor onion mail relay    #
  ###########################
  services.tor = {
    enable   = true;
    settings = {
      HiddenServiceDir     = "/persist/tor/hidden_service_mail";
      HiddenServiceVersion = 3;
      HiddenServicePort    = [
        "25  127.0.0.1:2525"
        "587 127.0.0.1:1587"
      ];
    };
  };

  ###########################
  # Postfix & mail user    #
  ###########################
  # Create the mailuser group & system user
  users.groups.mailuser = { };
  users.users.mailuser = {
    isSystemUser = true;
    group        = "mailuser";
    home         = "/var/lib/mail";
    shell        = "/run/current-system/sw/bin/nologin";
  };

  # Ensure /var/spool/postfix exists and owned by mailuser
  systemd.tmpfiles.rules = [
    "d /var/spool/postfix 0755 mailuser mailuser -"
  ];

  ###########################
  # Filesystems             #
  ###########################
  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  ###########################
  # Bootloader (GRUB)       #
  ###########################
  boot.loader.grub = {
    enable                = true;
    devices               = [ "/dev/sdc" ];  # ← adjust if your target stick has a different letter
    efiSupport            = true;            # for removable‐media (UEFI)
    efiInstallAsRemovable = true;
  };

  ###########################
  # Extras                  #
  ###########################
  # Add any extra packages you need here
  environment.systemPackages = with pkgs; [
    alpine
    mutt
    gnupg
  ];
}
