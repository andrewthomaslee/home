{inputs, ...}: {
  # ------ Per-System ------ #
  perSystem = {pkgs, ...}: {
    packages.ea-app = with pkgs; let
      iconFile = fetchurl {
        url = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/electronic-arts.svg";
        hash = "sha256-fFFS7EIafDz8TdiAnLVV/pS/X1aisno6Okq295bImng=";
      };

      # 1. Create a script that handles runtime checks and execution
      launcherScript = writeShellApplication {
        name = "ea-app";
        runtimeInputs = [
          wineWow64Packages.waylandFull
          winetricks
          cabextract
          coreutils
        ];
        text = ''
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
      };

      # 2. Automatically generate the system .desktop shortcut pointing to the script
      desktopItem = makeDesktopItem {
        name = "ea-app";
        exec = "${launcherScript}/bin/ea-app";
        icon = "${iconFile}";
        comment = "EA App via declarative Wine prefix wrapper";
        desktopName = "EA App";
        categories = ["Game"];
      };
    in
      # 3. Combine both the script and the shortcut into a single package
      symlinkJoin {
        name = "ea-app-wrapped";
        paths = [launcherScript desktopItem];
      };
  };
}
