
{ config, pkgs, lib, ... }:

{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    <nixpkgs/nixos/modules/profiles/hardened.nix>
  ];

  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" = { options = [ "noatime" "discard" ]; };

  fileSystems."/var/lib/tor" = {
    device = "/persist/tor";
    fsType = "none";
    options = [ "bind" ];
  };

  networking.hostName = "mailstick-vbox";
  networking.useDHCP  = true;
  networking.firewall.enable          = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

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
          { port = 25; target.addr = "127.0.0.1"; target.port = 2525; }
	  { port = 587; target.addr = "127.0.0.1"; target.port = 1587; }
        ];
      };
    };

    relay.exitPolicy = [ "reject *:*" ]; 
    
    settings = {
      ORPort = "auto";
    };
  };

  systemd.services."tor.service".serviceConfig = {
    Requires = [ "persist.mount" ];
    After    = [ "persist.mount" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p /persist/tor/onion/mailstick"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor/onion/mailstick"
      "${pkgs.coreutils}/bin/chmod 700 /persist/tor/onion/mailstick"
    ];
  };


  #services.openssh.enable = false;

  #systemd.coredump.enable = false;
  #boot.kernel.sysctl = {
  #  "kernel.kptr_restrict"          = 2;
  #  "net.ipv4.conf.all.forwarding"  = 0;
  #  "net.ipv4.icmp_echo_ignore_all" = 1;
  #};

  environment.systemPackages = with pkgs; [ 
    tor
    torsocks
    git 
  ];
}
