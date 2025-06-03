{ config, pkgs, lib, ... }:

{
  ################################################
  # 0) State Version                             #
  ################################################
  # Ensure NixOS knows you’re targeting 25.05
  system.stateVersion = "25.05";

  ################################################
  # 1) Import Hardened Profile + Hardware Config  #
  ################################################
  imports = [
    <nixpkgs/nixos/modules/profiles/hardened.nix>
    ./hardware-configuration.nix
  ];

  ################################################
  # 2) Bootloader (GRUB on /dev/sda)              #
  ################################################
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";
  # (Removed useEFI & canTouchEfiVariables for BIOS-only VM)

  ################################################
  # 3) Mount Options                             #
  ################################################
  # Root is defined in hardware-configuration.nix by UUID.
  # We only need noatime & discard:
  fileSystems."/" = {
    # device and fsType are already in hw config
    options = [ "noatime" "discard" ];
  };

  ################################################
  # 4) Networking & Firewall                     #
  ################################################
  networking.hostName = "mailstick-vbox";
  networking.useDHCP = true;                   # VM via DHCP
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];   # No incoming TCP
  networking.firewall.allowedUDPPorts = [ ];   # No incoming UDP

  ################################################
  # 5) Tor Service + Hidden Service on /persist   #
  ################################################
  services.tor = {
    enable        = true;
    client.enable = true;      # Tor in client mode
    relay.enable  = false;     # Not a relay
    enableGeoIP   = false;

    # New 25.05-style hidden service definition
    hiddenServices = {
      mailstick = {
        directory = "/persist/tor/hidden_service_mail";
        version   = 3;
        ports     = [
          { port = 25; targetAddress = "127.0.0.1"; targetPort = 2525; }
        ];
      };
    };

    settings = {
      ExitPolicy = [ "reject *:*" ];  # Do not allow any exit traffic
    };

    openFirewall    = false;   # Don’t open any clearnet ports for Tor
    torsocks.enable = true;    # Allow ‘torsocks <cmd>’ for CLI tools
  };

  # Ensure /persist is already mounted before tor.service starts, then create & secure hidden-service folder
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

  ################################################
  # 6) Disable SSH on Clearnet                   #
  ################################################
  services.openssh.enable = false;

  ################################################
  # 7) System Hardening                          #
  ################################################
  systemd.coredump.enable = false;  # Disable core dumps

  boot.kernel.sysctl = {
    "kernel.kptr_restrict"           = 2;  # Hide kernel pointers
    "net.ipv4.conf.all.forwarding"   = 0;
    "net.ipv6.conf.all.disable_ipv6" = 0;
    "net.ipv4.icmp_echo_ignore_all"  = 1;  # Ignore ping requests
  };

  ################################################
  # 8) Packages                                  #
  ################################################
  environment.systemPackages = with pkgs; [
    tor
  ];
}
