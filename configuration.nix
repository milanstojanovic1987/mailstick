{ config, pkgs, lib, nixpkgs, ... }:

{
  ############################################
  # 1. Base system & hardened profile        #
  ############################################
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    "${nixpkgs}/nixos/modules/profiles/hardened.nix"
  ];

  ############################################
  # 2. Bootloader                            #
  ############################################
  boot.loader.grub = {
    enable  = true;
    version = 2;
    devices = [ "/dev/sda" ];
  };

  ############################################
  # 3. Filesystems                           #
  ############################################
  fileSystems."/" = { options = [ "noatime" "discard" ]; };

  fileSystems."/var/lib/tor" = {
    device  = "/persist/tor";
    fsType  = "none";
    options = [ "bind" ];
  };

  ############################################
  # 4. Networking / Firewall                 #
  ############################################
  networking = {
    hostName = "mailstick-vbox";
    useDHCP  = true;

    firewall = {
      enable          = true;
      allowedTCPPorts = [ 2525 1587 ];
      allowedUDPPorts = [ ];
    };
  };

  ############################################
  # 5. Tor daemon + hidden service           #
  ############################################
  services.tor = {
    enable        = true;
    client.enable = true;
    relay.enable  = true;
    relay.role    = "relay";
    enableGeoIP   = false;

    settings = {
      HiddenServiceDir     = "/persist/tor/onion/mailstick";
      HiddenServiceVersion = 3;
      HiddenServicePort    = [ "25 127.0.0.1:25" ];
      ORPort               = "auto";
    };

    relay.exitPolicy = [ "reject *:*" ];
  };

  ############################################
  # Systemd service corrections              #
  ############################################
  systemd.services."tor".serviceConfig = {
    Requires     = [ "persist.mount" ];
    After        = [ "persist.mount" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p /persist/tor/onion/mailstick"
      "${pkgs.coreutils}/bin/chmod 700 /persist/tor/onion/mailstick"
    ];
  };

  ############################################
  # 6. Postfix – localhost-only relay        #
  ############################################
  services.postfix = {
    enable = true;

    config = {
      inet_interfaces     = "127.0.0.1";
      myhostname          = "mailstick-vbox.local";
      mydestination       = "localhost";
      relayhost           = "";
      compatibility_level = "3.6";
    };

    extraMasterConf = ''
      2525   inet  n  -  y  -  -  smtpd
      1587   inet  n  -  y  -  -  smtpd
    '';
  };

  ############################################
  # 7. Extra packages                        #
  ############################################
  environment.systemPackages = with pkgs; [
    tor
    torsocks
    git
  ];
}
