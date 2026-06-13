{...}: {
  # ------ NixOS Modules ------ #
  flake.nixosModules.amd = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.hostSpec.hardware.amd;
  in {
    options.hostSpec.hardware.amd.enable = lib.mkEnableOption "default amd configuration";

    config = lib.mkIf cfg.enable {
      nixpkgs.config.rocmSupport = true;

      environment.systemPackages = with pkgs.unstable; [
        amdgpu_top # GPU monitoring
      ];

      # Enable GPU acceleration
      hardware = {
        amdgpu.initrd.enable = true;
        graphics.enable = true;
      };

      systemd.tmpfiles.rules = let
        rocmEnv = pkgs.symlinkJoin {
          name = "rocm-combined";
          paths = with pkgs.rocmPackages; [
            rocblas
            hipblas
            clr
          ];
        };
      in [
        "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
      ];
    };
  };
}
