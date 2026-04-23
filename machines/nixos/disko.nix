{lib, ...}: {
  disko.devices = lib.mkForce {
    disk = {
      nvme0n1 = {
        name = "nvme0n1";
        device = "/dev/disk/by-id/nvme-WD_Blue_SN5100_500GB_25492N805944";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "1G";
              priority = 2;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            nixos = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = ["noatime"];
              };
            };
          };
        };
      };
    };
  };
}
