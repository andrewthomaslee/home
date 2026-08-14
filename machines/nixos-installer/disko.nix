{
  disko.devices.disk = {
    nixos = {
      device = "/dev/disk/by-id/usb-_USB_DISK_3.0_070807029C907132-0:0";
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
  };
}
