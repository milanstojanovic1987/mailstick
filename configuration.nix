{ config, pkgs, ... }:

{
  ################################################
  # 0) State Version                             #
  ################################################
  system.stateVersion = "25.05";

  ################################################
  # 1) Import only hardware-configuration.nix    #
  ################################################
  imports = [
    ./hardware-configuration.nix
  ];

  ################################################
  # 2) Networking & Firewall                     #
  ################################################
  networking.hostName = "mailstick-vbox";
  networking.useDHCP = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];   # Block all inbound TCP
  networking.firewall.allowedUDPPorts = [ ];   # Block all inbound UDP

  ################################################
  # 3) Tor Service + Hidden Service on /persist   #
  ################################################
  services.tor = {
    enable        = true;
    client.enable = true;   # Tor in client mode
    relay.enable  = false;  # Not a relay
    enableGeoIP   = false;

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

    openFirewall    = false;  # Don’t open any clearnet ports for Tor
    torsocks.enable = true;   # Allow torsocks for CLI tools
  };

  ################################################
  # 4) Disable SSH                                #
  ################################################
  services.openssh.enable = false;

  ################################################
  # 5) Minimal packages                           #
  ################################################
  environment.systemPackages = with pkgs; [
    tor
  ];
}
