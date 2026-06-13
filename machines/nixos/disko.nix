{
  disko.devices.disk.main = {
    device = "/dev/disk/by-id/nvme-Patriot_M.2_P300_1024GB_P300ZCCB250907339";
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
          size = "5G";
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
}
