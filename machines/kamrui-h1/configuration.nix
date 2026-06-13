{
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.jovian.nixosModules.default
  ];

  nixpkgs.config.rocmSupport = true;

  environment.systemPackages = with pkgs.unstable; [
    amdgpu_top # GPU monitoring
    llmfit # LLM system benchmarking
    cmake # Cross-platform, open-source build system generator
    steam-rom-manager # App for adding 3rd party games/ROMs as Steam launch items
    # gnome-software # for flatpaks
    # wine
    # bottles
    # wineWowPackages.waylandFull
    # winetricks
    # cabextract
    # gnutls
    # vulkan-tools
    (let
      # Define the Wine package we want to bundle with the wrapper
      wineRunner = pkgs.wineWowPackages.waylandFull;

      # 1. Create a script that handles runtime checks and execution
      launcherScript = pkgs.writeShellScriptBin "ea-app" ''
        # Ensure Wine, Winetricks, and utilities are available in the wrapper path
        export PATH="${pkgs.lib.makeBinPath [wineRunner pkgs.winetricks pkgs.cabextract]}:$PATH"
        export WINEPREFIX="$HOME/.ea-app"

        EXE_PATH="$WINEPREFIX/drive_c/Program Files/Electronic Arts/EA Desktop/EA Desktop/EADesktop.exe"

        # Check if EA App exists. If not, download and install it.
        if [ ! -f "$EXE_PATH" ]; then
          echo "EA App not found. Initializing a clean Wine prefix..."
          mkdir -p "$WINEPREFIX"

          # Install prerequisites silently (-q)
          echo "Installing core fonts and DXVK translation layers..."
          winetricks -q corefonts dxvk vkd3d d3dcompiler_47

          INSTALLER="${inputs.ea}"

          echo "Launching the EA installer. Please complete the setup steps..."
          wine "$INSTALLER"
        fi

        # Launch the application from its execution directory if it installed successfully
        if [ -f "$EXE_PATH" ]; then
          echo "Launching the EA App..."
          cd "$(dirname "$EXE_PATH")" || exit 1
          exec wine EADesktop.exe
        else
          echo "Error: EA App is still not installed."
          exit 1
        fi
      '';

      # 2. Automatically generate the system .desktop shortcut pointing to the script
      desktopItem = pkgs.makeDesktopItem {
        name = "ea-app";
        exec = "${launcherScript}/bin/ea-app";
        icon = "wine";
        comment = "EA App via declarative Wine prefix wrapper";
        desktopName = "EA App";
        categories = ["Game"];
      };
    in
      # 3. Combine both the script and the shortcut into a single package
      pkgs.symlinkJoin {
        name = "ea-app-wrapped";
        paths = [launcherScript desktopItem];
      })
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

  jovian = {
    hardware.has.amd.gpu = true;
    steam.enable = false;
  };

  services.orca.enable = false; # Disable screen reader
  # services.flatpak.enable = true; # Enable Flatpak

  # Steam
  #
  # Set game launcher: gamemoderun %command%
  #   Set this for each game in Steam, if the game could benefit from a minor
  #   performance tweak: YOUR_GAME > Properties > General > Launch > Options
  #   It's a modest tweak that may not be needed. Jovian is optimized for
  #   high performance by default.
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    gamemode = {
      enable = true;
      settings = {
        general.renice = 10;
        gpu = {
          apply_gpu_optimisations = "accept-responsibility"; # For systems with AMD GPUs
          gpu_device = 0;
          amd_performance_level = "high";
        };
      };
    };
  };
  networking.networkmanager.enable = lib.mkForce true; # Steam UI needs networkmanager

  hostSpec.services = {
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
}
