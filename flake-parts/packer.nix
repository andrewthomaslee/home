{...}: {
  # ------ Per-System ------ #
  perSystem = {inputs', ...}: {
    apps.packer-hcloud = inputs'.packer.apps.packer-hcloud-ext4-x86_64;
  };
}
