{self, ...}: {
  # For Andrew's PCs
  flake.homeModules.profile-netsa = {pkgs, ...}: {
    imports = [self.homeModules.default];
    config = {
      xdg.configFile."whisper-dictation/config.yaml".source = (pkgs.formats.yaml {}).generate "whisper-dictation-config" {
        hotkey = {
          modifiers = ["super"];
          key = "slash";
        };

        input_device = null;

        whisper = {
          model = "base";
          language = "en";
          threads = 4;
          use_gpu = true;
        };

        ui = {
          show_waveform = true;
          theme = "dark";
        };

        processing = {
          remove_filler_words = true;
          auto_capitalize = true;
          auto_punctuate = false;
        };

        typing = {
          key_delay = 0;
          key_hold = 0;
          start_delay = 0;
        };
      };
      # homeSpec options
      homeSpec = {
        xdg.enable = true;
        programs = {
          plasma-manager.enable = true;
          tmux.enable = true;
          bun.enable = true;
          direnv.enable = true;
          docker.enable = true;
          firefox.enable = true;
          ghostty.enable = true;
          git.enable = true;
          go.enable = true;
          k9s.enable = true;
          ksshaskpass.enable = true;
          media.enable = true;
          neovim.enable = true;
          password-store.enable = true;
          shell.enable = true;
          ssh.enable = true;
          starship.enable = true;
          uv.enable = true;
          vscode.enable = true;
          opencode.enable = true;
        };
      };
      # Home Options
      home.packages = with pkgs;
        [
          moscripts
          kubefetch
        ]
        ++ (with pkgs.unstable; [
          asciinema
          kalker
          lazyssh
          lazyjournal
          freelens-bin
        ]);
    };
  };
}
