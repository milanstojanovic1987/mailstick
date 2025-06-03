{ config, pkgs, lib, ... }:

{
  ################################################
  # 1) NixOS “state version” and hostname         #
  ################################################
  system.stateVersion = "23.11";       # adjust to match your ISO (e.g. "25.05" if you use a 25.05 installer)
  networking.hostName = "nixos-tor-test";
  time.timeZone       = "UTC";

  ########################################
  # 2) Filesystems + Mounts               #
  ########################################
  # We assume:
/dev/sda1 → EFI partition, FAT32, label="NIXOS-BOOT"
/dev/sda2 → root partition, ext4,  label="NIXOS-ROOT"
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

  # Use systemd-boot for EFI
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  ################################################
  # 3) Networking                             #
  ################################################
  # We will use NetworkManager (which handles DHCP automatically).
  networking.networkmanager.enable = true;
  # Do NOT set networking.useDHCP = true if NetworkManager is enabled,
  # as that causes a conflict.

  ################################################
  # 4) Users                                  #
  ################################################
  users.users.tester = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    password     = "secret123";  # change later after first login
  };

  # Allow members of ‘wheel’ to run sudo without a password
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  ################################################
  # 5) Tor Service (minimal)                   #
  ################################################
  # By default, NixOS’s Tor module inserts “SocksPort 0” (which disables the built-in SOCKS listener).
  # We override that using lib.mkForce so that the only SocksPort in the final torrc is 127.0.0.1:9050.
  services.tor = {
    enable   = true;

    settings = lib.mkForce {
      # EXACT capitalization: "SocksPort"
      SocksPort = "127.0.0.1:9050";
    };
  };

  ################################################
  # 6) SSH and Basic Packages                  #
  ################################################
  services.openssh.enable               = true;
  services.openssh.passwordAuthentication = false;
  services.openssh.permitRootLogin      = "no";

  environment.systemPackages = with pkgs; [
    vim     # editor
    curl    # to test HTTP/S
    wget
  ];

  ################################################
  # 7) (Optional) GUI or Text Consoles         #
  ################################################
  # If you want a minimal graphical environment, uncomment these:
  #
  # services.xserver.enable             = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;
  #
  # Otherwise, by default you’ll boot into a console login.

  ################################################
  # 8) Other Defaults (no extra DHCP, no extra   #
  #    Tor options)                              #
  ################################################
  # (Nothing else is strictly necessary for this minimal Tor + SSH setup.)
}
