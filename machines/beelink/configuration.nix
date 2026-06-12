{
  pkgs,
  lib,
  ...
}: {
  nixpkgs.config.rocmSupport = true;

  environment.systemPackages = with pkgs.unstable; [
    amdgpu_top # GPU monitoring
  ];

  # Enable GPU acceleration
  hardware = {
    amdgpu.initrd.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd
      ];
    };
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

  networking.networkmanager.enable = lib.mkForce true; # Steam UI needs networkmanager
}
