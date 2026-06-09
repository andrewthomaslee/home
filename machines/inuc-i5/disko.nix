{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-SAMSUNG_MZALQ512HALU-000L2_S4UKNF1NC91205";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "5G";
              type = "EF00";
              priority = 2;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077" "noatime"];
              };
            };
            nixos = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = ["noatime"];
                extraArgs = ["-L" "nixos"];
              };
            };
          };
        };
      };
      # sda = {
      #   type = "disk";
      #   device = "/dev/disk/by-id/ata-ST1000DM003-1SB102_Z9APETJA";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       data = {
      #         size = "100%";
      #         content = {
      #           type = "filesystem";
      #           format = "ext4";
      #           mountpoint = "/mnt/sda";
      #           mountOptions = ["noatime" "nofail"];
      #         };
      #       };
      #     };
      #   };
      # };
      # sdb = {
      #   type = "disk";
      #   device = "/dev/disk/by-id/ata-ST2000DX001-1NS164_Z4Z5RFRN";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       data = {
      #         size = "100%";
      #         content = {
      #           type = "filesystem";
      #           format = "ext4";
      #           mountpoint = "/mnt/sdb";
      #           mountOptions = ["noatime" "nofail"];
      #         };
      #       };
      #     };
      #   };
      # };
    };
  };
}
