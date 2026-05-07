{...}: {
  # ------ Per-System ------ #
  perSystem = {inputs', ...}: {
    packages.clan-cli = inputs'.clan-core.packages.clan-cli;
  };
}
