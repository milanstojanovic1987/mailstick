{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";  # matches your live-USB
  networking.hostName = "mailstick";
  time.timeZone     = "UTC";

  ########################################
  # Encrypted data partition (LUKS root) #
  ########################################
  boot.initrd.luks.devices = {
    data = {
      device  = "/dev/disk/by-label/DATA";
      preLVM  = true;
    };
  };

  ###########################
  # Tor onion mail relay    #
  ###########################
  services.tor.enable = true;
  services.tor.settings = {
    HiddenServiceDir     = "/persist/tor/hidden_service_mail";
    HiddenServiceVersion = 3;
    HiddenServicePort    = [
      "25 127.0.0.1:2525"
      "587 127.0.0.1:1587"
    ];
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

  # Ensure /var/spool/postfix exists before activation
  environment.etc."var/spool/postfix" = {
    target = "/var/spool/postfix";
    mode   = "0755";
  };

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
  boot.loader.grub.enable            = true;
  # Remove any old `boot.loader.grub.version` line if present
  boot.loader.grub.devices           = [ "/dev/sdc" ];  # ← change if needed
  # For UEFI removable-media installs, uncomment:
  # boot.loader.grub.efiSupport            = true;
  # boot.loader.grub.efiInstallAsRemovable = true;

  ###########################
  # (Any other services,   #
  #  users, packages, etc.) #
  ###########################
  # e.g.
  # environment.systemPackages = with pkgs; [ alpine mutt gnupg ];
}
