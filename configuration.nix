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
      allowedTCPPorts = [ 2525 1587 ];   # local SMTP submission
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

    relay.onionServices = {
      mailstick = {
        version = 3;
        map = [
          { port = 25;  target.addr = "127.0.0.1"; target.port = 2525; }
          { port = 587; target.addr = "127.0.0.1"; target.port = 1587; }
        ];
      };
    };

    relay.exitPolicy = [ "reject *:*" ];

    settings = { ORPort = "auto"; };
  };

  # Ensure /persist/tor exists before Tor starts
  systemd.services."tor.service".serviceConfig = {
    Requires     = [ "persist.mount" ];
    After        = [ "persist.mount" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p /persist/tor/onion/mailstick"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor/onion/mailstick"
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

    # ← fixed attribute name
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

  ############################################
  # 8. Optional extra hardening (commented)  #
  ############################################
  # services.openssh.enable = false;
  # systemd.coredump.enable = false;
  # boot.kernel.sysctl = {
  #   "kernel.kptr_restrict"          = 2;
  #   "net.ipv4.conf.all.forwarding"  = 0;
  #   "net.ipv4.icmp_echo_ignore_all" = 1;
  # };
}
