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
  # Use the 25.05‐style "devices" array, not the old "device":
  boot.loader.grub.devices = [ "/dev/sda" ];
  # (Remove any old "useEFI" or "canTouchEfiVariables" lines)

  ################################################
  # 3) Mount Options                             #
  ################################################
  # Root and /persist are defined in hardware-configuration.nix,
  # so we only specify noatime & discard here:
  fileSystems."/" = {
    options = [ "noatime" "discard" ];
  };

  ################################################
  # 4) Networking & Firewall                     #
  ################################################
  networking.hostName = "mailstick-vbox";
  networking.useDHCP = true;                   # VM via DHCP
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];   # No inbound TCP
  networking.firewall.allowedUDPPorts = [ ];   # No inbound UDP

  ################################################
  # 5) Tor Service + Hidden Service on /persist   #
  ################################################
  services.tor = {
    enable        = true;
    client.enable = true;      # Tor in client mode
    relay.enable  = false;     # Not a relay
    enableGeoIP   = false;

    # 25.05‐style hidden service definition:
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
      ExitPolicy = [ "reject *:*" ];  # No exit traffic allowed
    };

    openFirewall    = false;   # Don’t open any clearnet ports for Tor
    torsocks.enable = true;    # Allow “torsocks <cmd>” for CLI tools
  };

  # Ensure /persist is mounted before tor.service, then create & secure the hidden-service folder:
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
  # 6) Disable SSH                                #
  ################################################
  services.openssh.enable = false;

  ################################################
  # 7) System Hardening                           #
  ################################################
  systemd.coredump.enable = false;  # Disable core dumps

  boot.kernel.sysctl = {
    "kernel.kptr_restrict"           = 2;  # Hide kernel pointers
    "net.ipv4.conf.all.forwarding"   = 0;
    "net.ipv6.conf.all.disable_ipv6" = 0;
    "net.ipv4.icmp_echo_ignore_all"  = 1;  # Ignore ping requests
  };

  ################################################
  # 8) Installed Packages                        #
  ################################################
  environment.systemPackages = with pkgs; [
    tor
  ];
}
