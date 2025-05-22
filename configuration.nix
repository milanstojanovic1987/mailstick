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
  # Tor onion mail relay    #
  ###########################
  services.tor = {
    enable = true;
    hiddenServices = {
      mail = {
        version      = 3;
        storagePath  = "/persist/tor/hidden_service_mail";
        mappings = [
          { target = 25;  source = 2525; }
          { target = 587; source = 1587; }
          { target = 993; source = 1993; }
        ];
      };
    };
  };

  system.activationScripts.torPersist = {
    text = ''
      mkdir -p /persist/tor
      rm -rf /var/lib/tor
      ln -sf /persist/tor /var/lib/tor
    '';
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

  services.dovecot2.enable = true;
  services.dovecot2.mailLocation = "maildir:~/Maildir";

  ###########################
  # User account            #
  ###########################
  users.users.mailuser = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
  };

  ###########################
  # Persistent mail storage #
  ###########################
  fileSystems."/persist" = {
    device = "/dev/disk/by-label/DATA";
    fsType = "ext4";
  };

  system.activationScripts.persist = {
    text = ''
      mkdir -p /persist/{postfix,dovecot}
      ln -sf /persist/postfix    /var/spool/postfix
      ln -sf /persist/dovecot    /var/lib/dovecot
      mkdir -p /home/mailuser/Maildir
    '';
  };

  ###########################
  # Tools & firewall        #
  ###########################
  environment.systemPackages = with pkgs; [ vim curl git ];
  networking.firewall.enable = true;
}
