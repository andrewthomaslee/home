{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.determinate.nixosModules.default
  ];
  config = {
    # Universal hardware and firmware support for booting on arbitrary machines and USB
    hardware = {
      enableAllHardware = true;
      enableRedistributableFirmware = true;
    };

    boot = {
      initrd = {
        availableKernelModules = [
          "uas"
          "usb_storage"
          "usbcore"
          "sd_mod"
          "sr_mod"
          "xhci_pci"
          "ehci_pci"
          "ahci"
          "nvme"
          "mmc_block"
          "virtio_pci"
          "virtio_scsi"
          "virtio_blk"
          "virtio_net"
        ];
        kernelModules = [
          "uas"
          "usb_storage"
        ];
        systemd.emergencyAccess = true;
      };

      supportedFilesystems = [
        "btrfs"
        "ext4"
        "vfat"
        "xfs"
        "ntfs"
      ];
    };

    # NetworkManager for automatic DHCP on Ethernet and easy Wi-Fi connections via nmtui / nmcli
    networking.networkmanager.enable = lib.mkDefault true;

    # Tools for disk management, hardware diagnostics, and rescue/installation
    environment.systemPackages = with pkgs; [
      disko
      parted
      gptfdisk
      pciutils
      usbutils
      efibootmgr
      curl
      wget
      git
      neovim
      tmux
      htop
      btrfs-progs
      dosfstools
      e2fsprogs
    ];
  };
}
