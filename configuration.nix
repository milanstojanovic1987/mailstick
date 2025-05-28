{ config, pkgs, ... }:

{
  ###########################
  # Basic system settings   #
  ###########################
  imports = [ ];
  system.stateVersion = "23.11";
  networking.hostName = "mailstick";
  time.timeZone = "UTC";

  ###########################
  # Encrypted data partition#
  ###########################
  boot.initrd.luks.devices = {
    data = {
      device = "/dev/disk/by-label/DATA";
      preLVM = true;
    };
  };

  ###########################
  # Filesystems             #
  ###########################
  fileSystems."/" = {
    device = "/dev/mapper/cryptroot";
    fsType  = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType  = "vfat";
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/DATA";
    fsType  = "ext4";
  };

  fileSystems."/home" = {
    fsType  = "tmpfs";
    options = [ "size=256M" ];
  };

  ###########################
  # Bootloader (GRUB)       #
  ###########################
  boot.loader.systemd-boot.enable = false;    # we’ll use GRUB instead
  boot.loader.grub = {
    enable                = true;
    version               = 2;
    devices               = [ "/dev/sdc" ];  # your USB device
    efiSupport            = true;
    efiInstallAsRemovable = true;
  };

  ###########################
  # Tor onion mail relay    #
  ###########################
  services.tor.enable   = true;
  services.tor.settings = {
    HiddenServiceDir     = "/persist/tor/hidden_service_mail";
    HiddenServiceVersion = 3;
    HiddenServicePort    = [
      "25  127.0.0.1:2525"
      "587 127.0.0.1:1587"
      "993 127.0.0.1:1993"
    ];
  };
  system.activationScripts.torPersist = {
    text = ''
      mkdir -p /persist/tor
      rm -rf /var/lib/tor
      ln -sf /persist/tor /var/lib/tor
    '';
  };

  ###########################
  # Ensure mailuser exists  #
  ###########################
  users.groups.mailuser = { };               # create mailuser group
  users.users.mailuser = {
    isSystemUser = true;                     # no shell login
    group        = "mailuser";
    home         = "/var/lib/mail";
    shell        = pkgs.runCommandNoCC "nologin" {};
  };

  ###########################
  # Pre-create postfix spool#
  ###########################
  environment.etc."var/spool/postfix" = {
    target = "/var/spool/postfix";
    mode   = "0755";
  };

  ###########################
  # Mail services           #
  ###########################
  services.postfix.enable = true;
  services.postfix.config = {
    myhostname      = "mailstick.onion";
    inet_interfaces = [ "127.0.0.1" ];
    home_mailbox    = "Maildir/";
  };

  services.dovecot2.enable       = true;
  services.dovecot2.mailLocation = "maildir:~/Maildir";

  ###########################
  # Persistence wiring      #
  ###########################
  system.activationScripts.persist = {
    text = ''
      mkdir -p /persist/{postfix,dovecot,gpg}
      chown mailuser:mailuser /persist/gpg

      # link services into persist
      ln -sf /persist/postfix    /var/spool/postfix
      ln -sf /persist/dovecot    /var/lib/dovecot
      ln -sf /persist/gpg        /home/mailuser/.gnupg

      mkdir -p /home/mailuser/Maildir
    '';
  };

  ###########################
  # Tools & firewall        #
  ###########################
  environment.systemPackages = with pkgs; [
    vim
    curl
    git
    alpine
    gnupg
  ];
  networking.firewall.enable = true;
}
