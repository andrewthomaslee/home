# ---
# schema = "btrfs-single-disk-subvolumes"
# [placeholders]
# mainDisk = "/dev/disk/by-id/nvme-Patriot_M.2_P300_1024GB_P300ZCCB250907339"
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
{
  boot.loader.grub = {
    efiInstallAsRemovable = true;
    efiSupport = true;
  };

  disko.devices = {
    disk = {
      main = {
        name = "main-96dcc5de4a494c9cab562418ef93e693";
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
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };

      # Samsung SSD 860 EVO 500GB — shared Steam games library.
      # Disk/partition names match the existing partlabel `disk-sata-sata` set
      # when the drive was formatted, so disko's generated fileSystems entry
      # (/dev/disk/by-partlabel/disk-sata-sata) mounts the existing partition.
      # Normal nixos-rebuild does NOT reformat, the disko module only emits the
      # mount. Re-run via the disko CLI only to (re)format.
      sata = {
        type = "disk";
        device = "/dev/disk/by-id/ata-Samsung_SSD_860_EVO_500GB_S5B2NR0N426114V";
        content = {
          type = "gpt";
          partitions = {
            sata = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/mnt/sata";
                mountOptions = ["noatime" "nofail" "acl"];
                extraArgs = ["-L" "sata"];
              };
            };
          };
        };
      };

      # Seagate 2TB (ST2000DX001) — shared user drive for wife & netsa.
      # Disk/partition names match the existing partlabel `disk-sdb-data` set
      # when the drive was formatted, so disko's generated fileSystems entry
      # (/dev/disk/by-partlabel/disk-sdb-data) mounts the existing partition.
      # Formatting-only spec (run via the disko CLI to (re)format); normal
      # nixos-rebuild does NOT reformat, the disko module only emits the mount.
      sdb = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000DX001-1NS164_Z4Z5RFRN";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/mnt/hdd";
                mountOptions = ["noatime" "nofail" "acl"];
                extraArgs = ["-L" "hdd"];
              };
            };
          };
        };
      };
    };
  };

  # Automatic local snapshots
  # https://digint.ch/btrbk/doc/readme.html
  #$ systemctl start btrbk-<instance>
  services.btrbk = {
    instances."nix" = {
      onCalendar = "0/2:00";
      settings = {
        subvolume = "/nix";
        snapshot_create = "onchange";
        snapshot_dir = "/nix";
        snapshot_preserve = "16h 7d 2w";
        snapshot_preserve_min = "3d";
      };
    };
    instances."home" = {
      onCalendar = "0/2:00";
      settings = {
        subvolume = "/home";
        snapshot_dir = "/home";
        snapshot_preserve = "16h 7d 3w 2m";
        snapshot_preserve_min = "3d";
      };
    };
  };
}
