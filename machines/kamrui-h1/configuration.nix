{
  pkgs,
  lib,
  ...
}: {
  networking.networkmanager.enable = lib.mkForce true;

  hostSpec = {
    hardware.amd.enable = true;
    # config.jovian = {
    #   enable = true;
    #   steamui = false;
    #   amd = true;
    # };
    services = {
      flatpak.enable = true;
      ollama = {
        enable = true;
        package = pkgs.unstable.ollama-rocm;
        loadModels = [
          "gemma4:e4b"
          "gemma4:e2b"
          "qwen3.5:4b"
          "deepseek-v2:16b-lite-chat-q2_K"
          "codellama:7b-instruct"
          "codellama:7b-python"
          "codegemma:7b-instruct-q4_K_M"
          "codegemma:7b-code-q4_K_M"
          "phi4-mini:3.8b-q4_K_M"
          # "gemma4:e2b-it-qat"
          # "gemma4:e4b-it-qat"
        ];
      };
    };
  };
}
