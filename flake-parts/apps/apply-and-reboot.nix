{...}: {
  # ------ Per-System ------ #
  perSystem = {
    lib,
    self',
    ...
  }: {
    apps.apply-and-reboot = {
      type = "app";
      program = lib.getExe self'.packages.apply-and-reboot;
      meta = {
        mainProgram = "apply-and-reboot";
        description = "Apply latest NixOS configuration + delayed reboot to allow Terraform/SSH to exit cleanly";
      };
    };
  };
}
