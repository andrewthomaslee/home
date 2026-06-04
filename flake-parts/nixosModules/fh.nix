{...}: {
  flake.nixosModules.fh = {
    pkgs,
    lib,
    ...
  }: {
    systemd.services.apply-and-reboot = {
      description = "Apply latest NixOS configuration + delayed reboot to allow Terraform/SSH to exit cleanly";
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe pkgs.apply-and-reboot;
      };
    };
  };
}
