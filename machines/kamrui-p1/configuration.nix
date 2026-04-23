{pkgs, ...}: {
  # Enable GPU acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };
}
