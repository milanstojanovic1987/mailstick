{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName    = "mailstick";
  time.timeZone          = "UTC";

  ########################################
  # Encrypted data partition (LUKS root) #
  ########################################
  boot.initrd.luks.devices = {
    data = {
      # Use the GPT partition name "DATA" that you created in parted
      device = "/dev/disk/by-partlabel/DATA";
      preLVM = true;
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
    enable = true;
  
    # (you can remove your previous HiddenServiceDir & HiddenServicePort settings)
    settings = {
      # you can set a DataDirectory if you like, or let it default
      # DataDirectory = "/var/lib/tor";
    };
  
    hiddenServices = {
      mail = {
        directory = "/persist/tor/hidden_service_mail";
        version   = 3;
        ports = [
          { port = 25;  target = "127.0.0.1:2525"; }
          { port = 587; target = "127.0.0.1:1587"; }
        ];
      };
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
