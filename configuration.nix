{ config, pkgs, lib, ... }:

{
  ################################################
  # 1) NixOS “state version” and hostname         #
  ################################################
  system.stateVersion = "23.11";       # If using a 25.05 ISO, change this to "25.05"
  networking.hostName = "nixos-tor-test";
  time.timeZone       = "UTC";

  ########################################
  # 2) Filesystems + Mounts               #
  ########################################
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS-ROOT";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS-BOOT";
      fsType = "vfat";
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  ########################################
  # 3) Networking (NetworkManager only)   #
  ########################################
  networking.networkmanager.enable = true;
  # Do NOT include “networking.useDHCP” when using NetworkManager.

  ########################################
  # 4) Users                              #
  ########################################
  users.users.tester = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    password     = "secret123";   # change after first login
  };

  security.sudo.enable             = true;
  security.sudo.wheelNeedsPassword = false;

  ########################################
  # 5) Tor Service                        #
  ########################################
  services.tor = {
    enable   = true;

    # Override any default “SocksPort 0” by forcing exactly one SocksPort:
    settings = lib.mkForce {
      SocksPort = "127.0.0.1:9050";
    };
  };

  ########################################
  # 6) OpenSSH + Basic Packages          #
  ########################################
  services.openssh.enable               = true;
  services.openssh.passwordAuthentication = false;
  services.openssh.permitRootLogin      = "no";

  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
  ];

  ########################################
  # 7) (Optional) GUI                    #
  ########################################
  # services.xserver.enable             = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;
}
