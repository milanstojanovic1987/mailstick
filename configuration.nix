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
  # (root “/” is defined in hardware-configuration.nix)
  fileSystems."/" = { options = [ "noatime" "discard" ]; };

  # Bind-mount /persist/tor → /var/lib/tor so Tor can use /var/lib/tor as usual
  fileSystems."/var/lib/tor" = {
    device  = "/persist/tor";
    fsType  = "none";
    options = [ "bind" ];
  };

  # (We leave /persist itself to be mounted by hardware-configuration.nix,
  # so we do NOT define fileSystems."/persist" here.)

  ############################################
  # 4. Networking / Firewall                 #
  ############################################
  networking = {
    hostName = "mailstick-vbox";
    useDHCP  = true;

    firewall = {
      enable          = true;
      # allow only the submission ports (2525, 1587) on localhost
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

    # We have removed any relay.onionServices block, so Tor will only run
    # this one hidden service under /persist/tor/onion/mailstick.
    relay.exitPolicy = [ "reject *:*" ];
  };

  # Ensure /persist/tor exists before Tor starts, and create the onion path
  systemd.services."tor".serviceConfig = {
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
