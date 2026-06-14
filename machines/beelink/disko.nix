{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-512GB_SSD_MQ22W02008419";
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
