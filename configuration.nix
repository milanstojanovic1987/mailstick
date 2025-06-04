{ config, pkgs, lib, ... }:

{
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" = { options = [ "noatime" "discard" ]; };

  networking.hostName = "mailstick-vbox";
  networking.useDHCP  = true;
  networking.firewall.enable          = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  services.tor = {
    enable        = true;
    client.enable = true;
    relay.enable  = false;
    enableGeoIP   = false;

    relay.onionServices = {
      mailstick = {
        version = 3;
        map = [
          { port = 25;
            target.addr = "127.0.0.1";
            target.port = 2525;
          }
        ];
      };
    };

    settings = { ExitPolicy = [ "reject *:*" ]; };

    openFirewall    = false;
    torsocks.enable = true;
  };

  systemd.services."tor.service".serviceConfig = {
    Requires = [ "persist.mount" ];
    After    = [ "persist.mount" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p /persist/tor/hidden_service_mail"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor/hidden_service_mail"
      "${pkgs.coreutils}/bin/chmod 700 /persist/tor/hidden_service_mail"
    ];
  };

  services.openssh.enable = false;

  systemd.coredump.enable = false;
  boot.kernel.sysctl = {
    "kernel.kptr_restrict"          = 2;
    "net.ipv4.conf.all.forwarding"  = 0;
    "net.ipv4.icmp_echo_ignore_all" = 1;
  };

  environment.systemPackages = with pkgs; [ tor ];
}
