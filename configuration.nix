{ config, pkgs, ... }:

{
  # Import the official NixOS hardened security profile for strong default hardening
  imports = [
    <nixpkgs/nixos/modules/profiles/hardened.nix>  # Enables hardened kernel, grsecurity-like settings, AppArmor, etc.:contentReference[oaicite:6]{index=6}
    ./hardware-configuration.nix  # Hardware config (generated or adjusted for USB boot)
  ];

  # Bootloader configuration for USB (adjust device path as needed for your USB)
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";      # Install GRUB to USB drive MBR/EFI (/dev/sda as example)
  boot.loader.grub.useEFI = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Filesystem and mount options for security and USB longevity
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/<UUID-of-root>";   # use the actual UUID of the USB’s root partition
    fsType = "ext4";
    options = [ "noatime" "discard" ];             # noatime reduces metadata writes; discard if using SSD/flash
  };
  # (If using full disk encryption, you'd have boot.initrd.luks.devices and an encrypted / above)

  # Network configuration – default to DHCP for portability
  networking.hostName = "tor-messenger";
  networking.useDHCP = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];   # No inbound TCP ports open (all unsolicited ingress blocked):contentReference[oaicite:7]{index=7}
  networking.firewall.allowedUDPPorts = [ ];
  # (By default NixOS firewall denies incoming traffic:contentReference[oaicite:8]{index=8}. Above ensures even typical ports like SSH are closed.)

  # **Optional Tor-only egress rule**: Uncomment the lines below to block *all* non-Tor internet traffic.
  # This uses an iptables owner rule to DROP any new outbound connection from processes except the Tor daemon.
  #
  # networking.firewall.extraCommands = ''
  #   iptables -A OUTPUT -m owner ! --uid-owner tor -m conntrack --ctstate NEW -j DROP
  # '';
  #
  # With this “kill-switch,” only the Tor service user can initiate external connections, preventing clearnet leaks.

  # Tor service configuration
  services.tor = {
    enable = true;
    # Run Tor as a client (for our hidden service) but not as a public relay:
    client.enable = true;
    relay.enable = false;
    # Disable Tor GeoIP lookups for privacy (optional)
    enableGeoIP = false;
    # Tor hidden (onion) service for the messaging application:
    relay.onionServices = {
      messaging = {                        # name of our onion service
        version = 3;                       # use Tor v3 onion addresses:contentReference[oaicite:9]{index=9}:contentReference[oaicite:10]{index=10}
        # Map the onion service port to the local service's address/port
        map = [{
          port = 80;                       # onion will accept connections on port 80 (HTTP)
          target.addr = "127.0.0.1";       # redirect to local loopback...
          target.port = 8080;              # ...to the messaging app listening on 127.0.0.1:8080
        }];
        # The Tor service will automatically generate a private key and hostname for this onion.
        # Keys/hostname will be stored under /var/lib/tor/messaging/ (by default) for persistence.
      };
      # (Optional additional onion services can be defined similarly, e.g. for SSH below)
    };
    # Extra Tor daemon settings for security (mapped to torrc options)
    settings = {
      SocksPort = "unix:/var/lib/tor/socks.sock";  # Tor SOCKS via socket (no listening TCP port)
      ControlPort = "unix:/var/lib/tor/control.sock";  # Control port via socket (for Tor control, if needed)
      ExitPolicy = "reject *:*";               # We are not an exit node – reject all exit traffic:contentReference[oaicite:11]{index=11}
      #DisableAllSwap = 1;                     # (Optional) Prevent Tor from using swap (if memory constrained)
      #AvoidDiskWrites = 1;                    # (Optional) Avoid writing Tor state to disk when possible
    };
    # Do NOT open any firewall ports for Tor. (Tor will only make outbound connections to the Tor network.)
    openFirewall = false;
    # Enable torsocks wrapper globally (so CLI tools use Tor by default - optional)
    torsocks.enable = true;  # This will allow using `torsocks <command>` to route commands through Tor:contentReference[oaicite:12]{index=12}
  };

  # Messaging service configuration (placeholder).
  # Assuming "MailStock" is installed or deployed on the system and listens on localhost:8080.
  # If packaged:
  # services.<mailstock>.enable = true;  # (Example - replace with actual service if available)
  #
  # If running a custom service, define a systemd service for it:
  systemd.services.mailstock = {
    description = "MailStock Messaging Service (Tor Hidden)";
    after = [ "network.target" "tor.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "mailstock";            # run as unprivileged user (consider adding to users.users)
      Group = "mailstock";
      AmbientCapabilities = "";      # no ambient capabilities
      NoNewPrivileges = true;       # no privilege escalation allowed
      PrivateTmp = true;            # isolate /tmp
      ProtectSystem = "strict";     # /usr, /boot, /etc read-only for this service:contentReference[oaicite:13]{index=13}
      ProtectHome = true;           # /home and other sensitive dirs inaccessible:contentReference[oaicite:14]{index=14}
      # (Additional sandboxing: e.g. PrivateDevices, RestrictSUIDSGID, etc., can be added as needed)
    };
    environment = { /* e.g., any required environment variables */ };
    # If the MailStock app is a binary or script, specify the ExecStart:
    ExecStart = "${pkgs.mailstock}/bin/mailstock --config /etc/mailstock.conf";
    # If MailStock is not an existing Nix package, you may need to build or copy it into the system closure and reference its path.
  };

  # OpenSSH is disabled by default to avoid exposing SSH on clearnet
  services.openssh.enable = false;
  # (Optional) To allow SSH access **only via Tor**, you can enable SSH on localhost and create an onion for it:
  # services.openssh.enable = true;
  # services.openssh.listenAddresses = [ "127.0.0.1" ];
  # services.openssh.passwordAuthentication = false;
  # services.openssh.permitRootLogin = "no";
  # services.tor.relay.onionServices.sshd = {
  #   version = 3;
  #   map = [{ port = 22; target.addr = "127.0.0.1"; target.port = 22; }];
  # };
  # This will **not** open port 22 on clearnet, but will provide an SSH onion address (check /var/lib/tor/sshd/hostname).

  # System hardening and miscellaneous settings
  # Disable core dumps (prevent potentially sensitive info in dumps):contentReference[oaicite:15]{index=15}
  systemd.coredump.enable = false;
  # Make journald logs volatile (stored in RAM only, not persisted to disk)
  systemd.journald.storage = "volatile";
  systemd.journald.forwardToSyslog = false;
  # Misc kernel hardening via sysctl (some provided by hardened profile already)
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;        # Hide kernel pointers in /proc (harder for exploits)
    "net.ipv4.conf.all.forwarding" = 0;
    "net.ipv6.conf.all.disable_ipv6" = 0;  # (Set to 1 to disable IPv6 entirely if not needed)
    "net.ipv4.icmp_echo_ignore_all" = 1;   # Ignore ping requests (optional stealth)
  };

  # Packages (minimal base plus any needed tools)
  environment.systemPackages = with pkgs; [
    tor        # Tor client (though running as service, CLI tools like torsocks might be useful)
    # Add any admin tools or messaging app client if needed
  ];
}
