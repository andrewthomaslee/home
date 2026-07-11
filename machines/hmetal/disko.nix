{
  disko.devices.disk = {
    main = {
      type = "disk";
      device = "/dev/disk/by-id/ata-KINGSTON_SKC6001024G_50026B7785930E48";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };
          ESP = {
            size = "15G";
            type = "EF00";
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
              extraArgs = ["-L" "nixos"];
            };
          };
        };
      };
    };
    # disk1 = {
    #   type = "disk";
    #   device = "/dev/disk/by-id/ata-SAMSUNG_MZ7LM480HCHP-00003_S1YJNXAG900394";
    #   content = {
    #     type = "gpt";
    #     partitions = {
    #       nixos = {
    #         size = "100%";
    #         content = {
    #           type = "filesystem";
    #           format = "ext4";
    #           mountpoint = "/mnt/disk1";
    #           mountOptions = ["noatime"];
    #           extraArgs = ["-L" "disk1"];
    #         };
    #       };
    #     };
    #   };
    # };
    # disk2 = {
    #   type = "disk";
    #   device = "/dev/disk/by-id/ata-SAMSUNG_MZ7GE480HMHP-00003_S1M8NYAF700380";
    #   content = {
    #     type = "gpt";
    #     partitions = {
    #       nixos = {
    #         size = "100%";
    #         content = {
    #           type = "filesystem";
    #           format = "ext4";
    #           mountpoint = "/mnt/disk2";
    #           mountOptions = ["noatime"];
    #           extraArgs = ["-L" "disk2"];
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
