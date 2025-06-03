{ config, pkgs, ... }:

{
  ################################################
  # 1) NixOS “state version” and hostname          #
  ################################################
  system.stateVersion = "23.11";       # or whatever matches your installer ISO
  networking.hostName = "nixos-tor-test";
  time.timeZone       = "UTC";

  ########################
  # 2) Filesystems + Mounts
  ########################
  # — Replace /dev/sdaX with your actual partitions.
  # If you have a separate EFI partition, point it below.
  #
  # Example: /dev/sda1 = EFI (FAT32), /dev/sda2 = root (ext4 or btrfs, etc.)
  #
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS-ROOT";   # however you chose to label or device ID
      fsType = "ext4";                            # or your preferred fs
    };
    "/boot" = {
      device = "/dev/disk/by-label/NIXOS-BOOT";   # EFI partition, formatted FAT32
      fsType = "vfat";
    };
  };

  # If you do UEFI + systemd-boot, you need to set:
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
    # If you prefer GRUB on UEFI, you could replace the above with grub.enable = true, 
    # but for simplicity we use systemd-boot here.
  };

  ########################
  # 3) Networking (very basic DHCP)
  ########################
  networking.useDHCP = true;
  # If you need a static IP, you can configure it here, but DHCP is easiest to start.

  ########################
  # 4) Users
  ########################
  # Create an ordinary user so you can log in by default.
  users.users.tester = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "secret123";      # change this once you’re in!
  };
  # Allow “wheel” to do sudo:
  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  ########################
  # 5) Essential Services + Packages
  ########################
  # We’ll install NetworkManager so that DHCP always “just works” on most hardware/VMs.
  networking.networkmanager.enable = true;

  ########################
  # 6) Tor Service (minimal)
  ########################
  services.tor = {
    enable = true;
    # Don’t configure a HiddenService yet—let’s first prove that tor.service can come up.
    # We’ll add a HiddenServiceDir later once Tor itself is running.
    #
    # If you do want to test a HiddenService right away, you can uncomment:
    #
    # settings = {
    #   HiddenServiceDir     = "/var/lib/tor/hidden_service_test";
    #   HiddenServiceVersion = 3;
    #   HiddenServicePort    = [ "80 127.0.0.1:8080" ];
    # };
  };

  ########################
  # 7) Minimal “other” stuff
  ########################
  # If you want a working console + ssh, include these:
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;
  services.openssh.permitRootLogin = "no";

  environment.systemPackages = with pkgs; [
    vim      # so we have an editor
    curl     # to test connectivity
    wget
  ];

  ########################
  # 8) (Optional) GUI or Text Consoles
  ########################
  # If you are on a VM and want to just use the console, you can skip X11 entirely.
  # Uncomment the following only if you want a minimal desktop:
  #
  # services.xserver.enable = true;
  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.desktopManager.plasma5.enable = true;
}
