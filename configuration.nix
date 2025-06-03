{ config, pkgs, ... }:

{
  ################################################
  # 1) Import Hardened Profile + Hardware Config #
  ################################################
  imports = [
    <nixpkgs/nixos/modules/profiles/hardened.nix>
    ./hardware-configuration.nix
  ];

  ################################################
  # 2) Bootloader (installing GRUB onto /dev/sda)#
  ################################################
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";         # Adjust if your VM disk is not /dev/sda
  boot.loader.grub.useEFI = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ################################################
  # 3) LUKS Setup for /persist (DATA partition)  #
  ################################################
  # Expect /dev/disk/by-label/DATA to be a LUKS container.
  boot.initrd.luks.devices = {
    data = {
      device = "/dev/disk/by-label/DATA";
      preLVM = false;                          # We mount the decrypted device directly
    };
  };

  #############################################
  # 4) Filesystems (root + persist for Tor)   #
  #############################################
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS-ROOT";  # Label the root partition “NIXOS-ROOT”
    fsType = "ext4";
    options = [ "noatime" "discard" ];
  };

  fileSystems."/persist" = {
    device = "/dev/mapper/data";               # The decrypted LUKS device
    fsType = "ext4";
    options = [ "noatime" "discard" ];
  };

  ################################################
  # 5) Networking & Firewall                     #
  ################################################
  networking.hostName = "mailstick-vbox";
  networking.useDHCP = true;                   # Use DHCP inside VirtualBox
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];   # No inbound TCP ports
  networking.firewall.allowedUDPPorts = [ ];   # No inbound UDP ports

  # (If you want to enforce Tor-only egress in the VM, uncomment below)
  # networking.firewall.extraCommands = ''
  #   iptables -A OUTPUT -m owner ! --uid-owner tor -m conntrack --ctstate NEW -j DROP
  # '';

  ################################################
  # 6) Tor Service + Hidden Service on /persist  #
  ################################################
  services.tor = {
    enable = true;
    client.enable = true;
    relay.enable = false;
    enableGeoIP = false;

    relay.onionServices = {
      mailstick = {
        version = 3;
        # Put the onion keys under /persist/tor/hidden_service_mail
        Dir = "/persist/tor/hidden_service_mail";
        map = [{
          port = 25;            # Expose SMTP port 25 via onion
          target.addr = "127.0.0.1";
          target.port = 2525;    # Your MailStick MTA listens on 2525 locally
        }];
      };
    };

    settings = {
      SocksPort = "unix:/var/lib/tor/socks.sock";
      ControlPort = "unix:/var/lib/tor/control.sock";
      ExitPolicy = "reject *:*";
    };

    openFirewall = false;          # Don’t open any clearnet ports for Tor
    torsocks.enable = true;        # Allow “torsocks <cmd>” for CLI tools
  };

  # Ensure /persist is mounted before Tor, and create/secure the hidden-service folder
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
  # 7) MailStock (placeholder) Service User      #
  ################################################
  users.users.mailstock = {
    isSystemUser = true;
    createHome   = false;
  };

  ################################################
  # 8) Systemd Service for MailStock/MTA         #
  ################################################
  systemd.services.mailstock = {
    description = "MailStock Messaging Service (Tor Hidden)";
    after = [ "network.target" "tor.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "mailstock";
      Group = "mailstock";
      AmbientCapabilities = "";
      NoNewPrivileges      = true;
      PrivateTmp           = true;
      ProtectSystem        = "strict";
      ProtectHome          = true;
      WorkingDirectory     = "/var/lib/mailstock";
    };
    environment = { };
    ExecStart = "${pkgs.mailstock}/bin/mailstock --config /etc/mailstock.conf";
  };

  ################################################
  # 9) Disable SSH on Clearnet                   #
  ################################################
  services.openssh.enable = false;

  ################################################
  # 10) System Hardening                         #
  ################################################
  systemd.coredump.enable = false;               # Disable core dumps
  systemd.journald.storage = "volatile";         # Logs in RAM only
  systemd.journald.forwardToSyslog = false;

  boot.kernel.sysctl = {
    "kernel.kptr_restrict"            = 2;
    "net.ipv4.conf.all.forwarding"    = 0;
    "net.ipv6.conf.all.disable_ipv6"  = 0;
    "net.ipv4.icmp_echo_ignore_all"   = 1;
  };

  ################################################
  # 11) Installed Packages                       #
  ################################################
  environment.systemPackages = with pkgs; [
    tor
    # Add any additional admin tools here if needed
  ];
}
