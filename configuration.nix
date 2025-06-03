{ config, pkgs, ... }:

{
  ################################################
  # 1) NixOS “state version” and hostname          #
  ################################################
  system.stateVersion = "23.11";       # adjust if your ISO is a different version
  networking.hostName = "nixos-tor-test";
  time.timeZone       = "UTC";

  ########################
  # 2) Filesystems + Mounts
  ########################
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

  ########################
  # 3) Networking (very basic DHCP)
  ########################
  networking.useDHCP = true;

  ########################
  # 4) Users
  ########################
  users.users.tester = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "secret123";      # you can change this later
  };
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  ########################
  # 5) Essential Services + Packages
  ########################
  networking.networkmanager.enable = true;

  ########################
  # 6) Tor Service (minimal)
  ########################
  services.tor = {
    enable = true;
  };

  ########################
  # 7) Minimal “other” stuff
  ########################
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  services.openssh.permitRootLogin = "no";

  environment.systemPackages = with pkgs; [
    vim
    curl
    wget
  ];

  ########################
  # 8) (Optional) GUI or Text Consoles
  ########################
  # services.xserver.enable = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;
}
