{pkgs, ...}: {
  # Enable GPU acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  home-manager.users.root.homeSpec.programs.k9s.enable = true;
}
