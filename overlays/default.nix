{
  inputs,
  self,
}: final: _prev: {
  # add unstable branch of nixpkgs accessable as `pkgs.unstable`
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  clan-cli = inputs.clan-core.packages.${final.stdenv.hostPlatform.system}.clan-cli;

  zen-browser = inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.default;
  moscripts = inputs.moscripts.packages.${final.stdenv.hostPlatform.system}.default;
  kubefetch = inputs.kubefetch.packages.${final.stdenv.hostPlatform.system}.default;
  devenv = inputs.devenv.packages.${final.stdenv.hostPlatform.system}.devenv;

  k3s = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.k3s_1_35;
  rke2 = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system}.rke2_1_35;

  tfctl = self.packages.${final.stdenv.hostPlatform.system}.tfctl;
  longhornctl = self.packages.${final.stdenv.hostPlatform.system}.longhornctl;
  vcluster = self.packages.${final.stdenv.hostPlatform.system}.vcluster;
  splashtop-streamer = self.packages.${final.stdenv.hostPlatform.system}.splashtop-streamer;
  headroom = self.packages.${final.stdenv.hostPlatform.system}.headroom;
  headroom-slim = self.packages.${final.stdenv.hostPlatform.system}.headroom-slim;
  artifacthub-mcp = self.packages.${final.stdenv.hostPlatform.system}.artifacthub-mcp;
  kubernetes-mcp-server = self.packages.${final.stdenv.hostPlatform.system}.kubernetes-mcp-server;
  opencode-nixd-scaffold = self.packages.${final.stdenv.hostPlatform.system}.opencode-nixd-scaffold;
  # OpenCode v2 CLI, patched: upstream's nix postInstall (tag v2.0.16 and
  # dev HEAD, 2026-09-24) still runs `opencode completion` — a subcommand
  # that no longer exists in v2. The default handler reads it as a
  # directory argument and chdir's into it, failing the build with ENOENT.
  # v2 exposes shell completions via the `--completions <shell>` global
  # flag (effect CLI), so regenerate them with that.
  opencode = inputs.opencode.packages.${final.stdenv.hostPlatform.system}.opencode.overrideAttrs (old: {
    # Desktop sidecar fix (splash-screen hang #2): the v2 CLI's service
    # registration filename is channel-derived (service-config.ts
    # filename(): latest/dev/beta/next -> flat "service.json", anything
    # else -> "service-<channel>.json"), and OPENCODE_CHANNEL is a
    # compile-time constant. Upstream's nix packaging bakes "prod", so
    # `opencode serve --service` registers at service-prod.json while the
    # desktop app's bundled @opencode/client polls ONLY the flat
    # ~/.local/state/opencode/service.json — the two never meet, the
    # client respawns contenders forever and the app hangs on its splash.
    # Build with channel "latest" so both sides agree on the flat
    # filename (also the default port 0xc0de); the channel is otherwise
    # inert here (it only names self-update artifacts we never use).
    env = (old.env or {}) // {OPENCODE_CHANNEL = "latest";};
    postInstall = final.lib.optionalString (final.stdenv.buildPlatform.canExecute final.stdenv.hostPlatform) ''
      installShellCompletion --cmd opencode \
        --bash <($out/bin/opencode --completions bash) \
        --zsh <(SHELL=/bin/zsh $out/bin/opencode --completions zsh)
      installShellCompletion --cmd opencode2 \
        --bash <($out/bin/opencode2 --completions bash) \
        --zsh <(SHELL=/bin/zsh $out/bin/opencode2 --completions zsh)
    '';
  });
  opencode-desktop = let
    # Upstream's nix/electron.nix pins stale electron SHASUMS (the comment
    # says 42.10.1) while packages/desktop depends on electron 44.4.3 — the
    # zip fixed-output derivation fails. Re-pinned from the official
    # v44.4.3 SHASUMS256.txt; headers from
    # https://artifacts.electronjs.org/headers/dist/v44.4.3/ (fetchzip
    # hashes the unpacked tree).
    electron-v44_4_3 = let
      generic = final.callPackage (inputs.nixpkgs + "/pkgs/development/tools/electron/binary/generic.nix") {};
      # nixpkgs#563260: electron 44+ no longer ships libGLESv2/libEGL
      # (Chromium statically links libGL/vulkan-loader), so generic.nix's
      # "patch libANGLE" postFixup block matches no files and patchelf
      # aborts the build. Drop that block; the nixpkgs fix (8073a5176ca7)
      # postdates the nixpkgs this flake follows.
      base = generic "44.4.3" {
        aarch64-linux = "61f084a5ac0f1835efc12b9db17042d92c8c617b03578f96a888acd4a05a0b10";
        x86_64-linux = "fe880a7e37160cfd4e00193bc4c713ead7a778abfe74860a2d36d86fd0be48a8";
        aarch64-darwin = "6b728f5dcfae74f3f936f2bca5b3cd9b9659ffea464f67939f004acb55425a85";
        x86_64-darwin = "015b52631d92187b552ff4e047255f596a7af4707e388a5890951f0b2645764e";
        headers = "sha256-QPkX+99kArlQhhbgOZe+Hsk28G5cadkUy0G0cIDtEh8=";
      };
    in
      base.overrideAttrs (old: {
        # postFixup blocks are blank-line separated; drop the one patching
        # the removed libANGLE libs.
        postFixup = final.lib.concatStringsSep "\n\n" (final.lib.filter
          (block: !(final.lib.hasInfix "libANGLE" block))
          (final.lib.splitString "\n\n" (old.postFixup or "")));
      });
    # desktop.nix derives electron internally (`callPackage
    # ./electron.nix`), so intercept that call and hand it the re-pinned
    # electron instead.
    callPackage = p: args:
      if final.lib.hasSuffix "electron.nix" (toString p)
      then electron-v44_4_3
      else final.callPackage p args;
  in
    (final.callPackage "${inputs.opencode}/nix/desktop.nix" {
      inherit (final) opencode;
      inherit callPackage;
    }).overrideAttrs (old: {
      # Upstream's buildPhase copies only the CLI binary into
      # OPENCODE_CLI_DIST, but its own copyCliToResources prebuild also
      # reads a package.json next to it (CLI version stamping) — write one.
      buildPhase =
        builtins.replaceStrings
        ["cp ${final.opencode}/bin/opencode \"$OPENCODE_CLI_DIST/$cli_package/bin/opencode\""]
        [
          ''
            # Nix packaging fix (splash-screen hang): upstream expects the
            # bundled CLI to be a single standalone executable, but the Nix
            # opencode package's bin/opencode is a 16 KB makeBinaryWrapper
            # shim that execs its SIBLING .opencode-wrapped (the 350 MB
            # real CLI). The desktop app's installCli() copies ONLY this
            # one file into the user profile at runtime, so the shim lands
            # there alone, the `opencode-cli serve --service` background
            # service dies instantly and never registers
            # ~/.local/state/opencode/service.json — the renderer waits on
            # the splash screen forever. Ship a self-contained launcher
            # instead: absolute store paths survive the copy anywhere, and
            # ripgrep stays on the sidecar's PATH exactly as the wrapped
            # CLI expects.
            cat > "$OPENCODE_CLI_DIST/$cli_package/bin/opencode" <<'LAUNCHER'
            #!/bin/sh
            export PATH=${final.lib.makeBinPath [final.ripgrep]}:"$PATH"
            exec ${final.opencode}/bin/.opencode-wrapped "$@"
            LAUNCHER
            chmod +x "$OPENCODE_CLI_DIST/$cli_package/bin/opencode"
            printf '{"name":"%s","version":"%s"}\n' "$cli_package" "${final.opencode.version}" > "$OPENCODE_CLI_DIST/$cli_package/package.json"
          ''
        ]
        old.buildPhase;
    });
  # OpenCode plugins (hermetic builds; entries referenced by store path).
  cc-safety-net = self.packages.${final.stdenv.hostPlatform.system}.cc-safety-net;
  opencode-morph-fast-apply = self.packages.${final.stdenv.hostPlatform.system}.opencode-morph-fast-apply;
  opencode-mem = self.packages.${final.stdenv.hostPlatform.system}.opencode-mem;

  apply-and-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-and-reboot;
  apply-to-reboot = self.packages.${final.stdenv.hostPlatform.system}.apply-to-reboot;
  apply-now = self.packages.${final.stdenv.hostPlatform.system}.apply-now;
  apply-test = self.packages.${final.stdenv.hostPlatform.system}.apply-test;
  apply-dry-activate = self.packages.${final.stdenv.hostPlatform.system}.apply-dry-activate;
}
