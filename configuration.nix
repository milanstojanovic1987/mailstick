{ config, pkgs, lib, ... }:

{
  ############################################
  # 1. Base system & imports                 #
  ############################################
  system.stateVersion = "25.05";

  imports = [
    ./hardware-configuration.nix
    # Uncomment the next line to enable NixOS’s hardened profile
    # <nixpkgs/nixos/modules/profiles/hardened.nix>
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
  # Root (example: ext4 on /dev/mapper/data)
  fileSystems."/" = {
    options = [ "noatime" "discard" ];
  };

  # Bind-mount Tor’s state onto the encrypted /persist volume
  fileSystems."/var/lib/tor" = {
    device  = "/persist/tor";
    fsType  = "none";
    options = [ "bind" ];
  };

  ############################################
  # 4. Networking                            #
  ############################################
  networking = {
    hostName = "mailstick-vbox";
    useDHCP  = true;

    firewall = {
      enable          = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };

  ############################################
  # 5. Tor daemon + hidden service           #
  ############################################
  services.tor = {
    enable        = true;
    client.enable = true;

    # Must be a relay for the onion-service section to be applied
    relay.enable  = true;
    enableGeoIP   = false;

    # Hidden-service definition
    relay.onionServices = {
      mailstick = {
        version   = 3;
        directory = "/var/lib/tor/hidden_service_mail";
        map = [
          { port = 25;  target.addr = "127.0.0.1"; target.port = 2525; }
          { port = 587; target.addr = "127.0.0.1"; target.port = 1587; }
        ];
      };
    };

    # Non-exit relay
    relay.exitPolicy = [ "reject *:*" ];
  };

  # Ensure /persist/tor exists and has correct perms before Tor starts
  systemd.services."tor.service".serviceConfig = {
    Requires     = [ "persist.mount" ];
    After        = [ "persist.mount" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/mkdir -p /persist/tor/hidden_service_mail"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor"
      "${pkgs.coreutils}/bin/chown tor:tor /persist/tor/hidden_service_mail"
      "${pkgs.coreutils}/bin/chmod 700 /persist/tor/hidden_service_mail"
    ];
  };

  ############################################
  # 6. Extra packages                        #
  ############################################
  environment.systemPackages = with pkgs; [
    tor
    torsocks
  ];

  ############################################
  # 7. Optional extra hardening (commented)  #
  ############################################
  # services.openssh.enable = false;
  # systemd.coredump.enable = false;
  # boot.kernel.sysctl = {
  #   "kernel.kptr_restrict"           = 2;
  #   "net.ipv4.conf.all.forwarding"   = 0;
  #   "net.ipv4.icmp_echo_ignore_all"  = 1;
  # };
}
