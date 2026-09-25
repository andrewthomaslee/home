{lib, ...}: {
  perSystem = {pkgs, ...}: let
    # ---- Shared helper: bun.lock -> node_modules fixed-output derivation ----
    # nixpkgs (as of 26.11-unstable) has no buildBunModule, so bun.lock-only
    # repos are built via a fixed-output derivation that runs
    # `bun install --frozen-lockfile` with network access and pins the
    # resulting node_modules tree by hash.
    bunNodeModules = {
      name,
      srcPath,
      prod ? true,
      outputHash,
    }:
    # runCommand-based FOD (fetchurl pattern): network is allowed and the
    # node_modules tree is pinned by hash.
      pkgs.runCommand name {
        nativeBuildInputs = [pkgs.bun];
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        inherit outputHash;
      } ''
        cp -r ${srcPath} ./repo
        chmod -R u+w ./repo
        cd ./repo
        export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
        export HOME=$TMPDIR/home
        mkdir -p $HOME
        bun install --frozen-lockfile --ignore-scripts --no-progress ${
          lib.optionalString prod "--production"
        }
        mkdir -p $out
        cp -r node_modules $out/node_modules
      '';

    # Assemble a plugin package root: source + node_modules (+ optional
    # build). The plugin entry referenced by opencode's `plugin` array is
    # a path inside this output, resolved by opencode's Bun runtime.
    mkBunPlugin = {
      pname,
      version,
      src,
      entry,
      prod ? true,
      preBuild ? "",
      postBuild ? "",
      nativeBuildInputs ? [],
      depsOutputHash,
    }: let
      nodeModules = bunNodeModules {
        name = "${pname}-${version}-bun-deps";
        inherit prod;
        srcPath = src;
        outputHash = depsOutputHash;
      };
    in
      # Assemble: source + node_modules (+ optional build). The plugin
      # entry referenced by opencode's `plugin` array is a path inside this
      # output, resolved by opencode's Bun runtime.
      pkgs.runCommand "${pname}-${version}" {
        nativeBuildInputs = [pkgs.bun] ++ nativeBuildInputs;
        passAsFile = ["preBuild" "postBuild"];
        inherit preBuild postBuild;
      } ''
        cp -r ${src} ./repo
        chmod -R u+w ./repo
        cd ./repo
        cp -r ${nodeModules}/node_modules ./node_modules
        chmod -R u+w ./node_modules
        export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
        export HOME=$TMPDIR/home
        mkdir -p $HOME
        source "$preBuildPath"
        source "$postBuildPath"
        mkdir -p $out/share/opencode-plugins/${pname}
        cp -r . $out/share/opencode-plugins/${pname}/
        rm -rf $out/share/opencode-plugins/${pname}/node_modules/.cache
        test -e $out/share/opencode-plugins/${pname}/${entry} || { echo "plugin entry missing: ${entry}"; exit 1; }
      '';
  in {
    # ---- CC Safety Net ----
    # dist/ is committed upstream and the plugin has ZERO runtime deps, so
    # the pinned source tree IS the package; entry = dist/index.js.
    # v2.4.6 is required for OpenCode v2: its default export is a native
    # V2 plugin ({ id, effect }); v2.4.1 only shipped the V1 hook shape.
    packages = {
      cc-safety-net = let
        version = "2.4.6";
        src = pkgs.fetchFromGitHub {
          owner = "kenryu42";
          repo = "cc-safety-net";
          rev = "v${version}";
          hash = "sha256-c5st4aYU6kL+A4/T9g9rE8Ff7vKSTufB7TAoLv3CUbA=";
        };
      in
        pkgs.runCommand "cc-safety-net-${version}" {} ''
          mkdir -p $out/share/opencode-plugins/cc-safety-net
          cp -r ${src}/. $out/share/opencode-plugins/cc-safety-net/
          test -e $out/share/opencode-plugins/cc-safety-net/dist/index.js
        '';

      # ---- opencode-morph-fast-apply ----
      # main = index.ts (opencode's Bun runtime loads TS directly); deps are
      # pure JS (@opencode-ai/plugin, @opencode/plugin, diff). Also ships the
      # always-on instructions/morph-tools.md wired into settings.instructions.
      # Pinned to trunk c185cb88 (2026-09-23, "feat(plugin): support OpenCode
      # V2"): the default export became a dual-shape object ({ id, setup }
      # for V2 + legacy `server` adapter); the v1.11.0 release tag predates
      # V2 support, so re-pin to the next tagged release when one appears.
      opencode-morph-fast-apply =
        (mkBunPlugin {
          pname = "opencode-morph-fast-apply";
          version = "1.11.0";
          src = pkgs.fetchFromGitHub {
            owner = "JRedeker";
            repo = "opencode-morph-fast-apply";
            rev = "c185cb8812b35c7ae1e97093468f1776843e065b";
            hash = "sha256-M3kxGwhlaGbEumJGF9ok1tPJSZO/IY37LNeNWSdRNT8=";
          };
          entry = "index.ts";
          depsOutputHash = "sha256-38IVy2EyoN5nmK9qcvBHnKsscmFsL5jtfVDAT6/UIUA=";
        })
        // {
          passthru.instructions = "instructions/morph-tools.md";
        };

      # ---- opencode-mem ----
      # Builds dist/ (tsc) + the web UI (vite in web/). Includes native
      # onnxruntime-node prebuilds -> autoPatchelfHook rewrites their ELF
      # deps to the nix store so dlopen into opencode's Bun works on NixOS.
      # Pinned to main cec1de48 (2026-09-18, "feat: add OpenCode v2 plugin
      # support"): the V2 entry is src/v2/plugin.ts -> dist/v2/plugin.js
      # (default export `{ id, setup }` adapter around the V1 plugin); the
      # v2.26.0 release tag predates it, so re-pin when v2.27.0 ships.
      opencode-mem = let
        version = "2.26.0";
        src = pkgs.fetchFromGitHub {
          owner = "tickernelz";
          repo = "opencode-mem";
          rev = "cec1de4834567f9fca9970942712ab7559ede142";
          hash = "sha256-kGTvKt86tGFEB5glOCZVHuCQ1/gmpyot9D0o63Qa9hY=";
        };
        nodeModules = bunNodeModules {
          name = "opencode-mem-${version}-bun-deps";
          prod = false; # build needs typescript (devDep)
          srcPath = src;
          outputHash = "sha256-hM+dJxirrc29vArFfdE5eH3PbJtiNmAeRwImcBiDrS0=";
        };
        webNodeModules = bunNodeModules {
          name = "opencode-mem-${version}-web-bun-deps";
          prod = false;
          outputHash = "sha256-2N4sxjEoUtWoTuGMRbQ/57U1XyRELyFzGxzUVwafBkQ=";
          srcPath = pkgs.runCommand "opencode-mem-web-src" {} ''
            mkdir -p $out
            cp -r ${src}/web/. $out/
          '';
        };
      in
        pkgs.runCommand "opencode-mem-${version}" {
          nativeBuildInputs = [
            pkgs.bun
            pkgs.autoPatchelfHook
            # Native libs referenced by onnxruntime-node prebuilds.
            pkgs.stdenv.cc.cc.lib
          ];
        } ''
          cp -r ${src} ./repo
          chmod -R u+w ./repo
          cd ./repo
          cp -r ${nodeModules}/node_modules ./node_modules
          cp -r ${webNodeModules}/node_modules ./web/node_modules
          chmod -R u+w ./node_modules ./web/node_modules
          export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
          export HOME=$TMPDIR/home
          mkdir -p $HOME
          # Upstream `bun run build` = `bunx tsc && bun run web:build`.
          # bunx probes the network offline, and node_modules/.bin shims use
          # `#!/usr/bin/env` (absent in the sandbox), so run the tools'
          # JS entries directly with bun.
          bun ./node_modules/typescript/bin/tsc
          (
            cd web
            bun ./node_modules/typescript/bin/tsc -b
            bun ./node_modules/vite/bin/vite.js build
          )
          mkdir -p $out/share/opencode-plugins/opencode-mem
          cp -r . $out/share/opencode-plugins/opencode-mem/
          rm -rf $out/share/opencode-plugins/opencode-mem/node_modules/.cache           $out/share/opencode-plugins/opencode-mem/web/node_modules
          # Patch onnxruntime prebuilds so dlopen into opencode's Bun resolves
          # the nix store libs on NixOS.
          autoPatchelf $out/share/opencode-plugins/opencode-mem/node_modules 2>/dev/null || true
          # V2 plugin adapter entry (src/v2/plugin.ts -> dist/v2/plugin.js);
          # the V1-only dist/plugin.js default export no longer loads in v2.
          test -e $out/share/opencode-plugins/opencode-mem/dist/v2/plugin.js || { echo "plugin entry missing: dist/v2/plugin.js"; exit 1; }
        '';
    };
  };
}
