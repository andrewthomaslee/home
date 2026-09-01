{
  disko.devices = {
    disk = {
      main = {
        name = "main-cw3jfbnbpybwr53244io7qtsz6o6zr1e";
        device = "/dev/disk/by-id/nvme-G932E1Q_1T_YALT002964T";
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
              size = "16G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "--force"
                  "--label root"
                ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:3"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:5"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:6"
                      "noatime"
                    ];
                  };
                  "@netsa" = {
                    mountpoint = "/home/netsa";
                    mountOptions = [
                      "compress=zstd:7"
                      "noatime"
                    ];
                  };
                  "@wife" = {
                    mountpoint = "/home/wife";
                    mountOptions = [
                      "compress=zstd:7"
                      "noatime"
                    ];
                  };
                  "@steam" = {
                    mountpoint = "/mnt/steam";
                    mountOptions = [
                      "compress=zstd:5"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
