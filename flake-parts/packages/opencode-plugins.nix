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
    packages.cc-safety-net = let
      version = "2.4.1";
      src = pkgs.fetchFromGitHub {
        owner = "kenryu42";
        repo = "cc-safety-net";
        rev = "v${version}";
        hash = "sha256-EhAw23cmIf7R9n8AQC7zayyYe0OGoNudMW+uZaYZWQU=";
      };
    in
      pkgs.runCommand "cc-safety-net-${version}" {} ''
        mkdir -p $out/share/opencode-plugins/cc-safety-net
        cp -r ${src}/. $out/share/opencode-plugins/cc-safety-net/
        test -e $out/share/opencode-plugins/cc-safety-net/dist/index.js
      '';

    # ---- opencode-morph-fast-apply ----
    # main = index.ts (opencode's Bun runtime loads TS directly); deps are
    # pure JS (@opencode-ai/plugin, diff). Also ships the always-on
    # instructions/morph-tools.md wired into settings.instructions.
    packages.opencode-morph-fast-apply =
      (mkBunPlugin {
        pname = "opencode-morph-fast-apply";
        version = "1.11.0";
        src = pkgs.fetchFromGitHub {
          owner = "JRedeker";
          repo = "opencode-morph-fast-apply";
          rev = "v1.11.0";
          hash = "sha256-MzMUlSGLz5diYWwdurE4Cxhb4bWqdm3D1DUE2yVW+PY=";
        };
        entry = "index.ts";
        depsOutputHash = "sha256-+FRm72hHv0pc68WMFNfU0PJVRm3NSMHObAmUGvPjlgA=";
      })
      // {
        passthru.instructions = "instructions/morph-tools.md";
      };

    # ---- opencode-devcontainers ----
    # main = plugin/index.js (committed plain JS); single pure-JS dep.
    packages.opencode-devcontainers = mkBunPlugin {
      pname = "opencode-devcontainers";
      version = "0.5.1";
      src = pkgs.fetchFromGitHub {
        owner = "athal7";
        repo = "opencode-devcontainers";
        rev = "v0.5.1";
        hash = "sha256-/+J34EYEQ9TIJinN4/Ce1pM2uzOFe+FvloZC0iYL304=";
      };
      entry = "plugin/index.js";
      depsOutputHash = "sha256-ZWg7TPQCdQCuYsvTAeu0WXQtwjk3EpMKXIM555Rm1a8=";
    };

    # ---- opencode-mem ----
    # Builds dist/plugin.js (tsc) + the web UI (vite in web/). Includes
    # native onnxruntime-node prebuilds -> autoPatchelfHook rewrites their
    # ELF deps to the nix store so dlopen into opencode's Bun works on
    # NixOS.
    packages.opencode-mem = let
      version = "2.26.0";
      src = pkgs.fetchFromGitHub {
        owner = "tickernelz";
        repo = "opencode-mem";
        rev = "v${version}";
        hash = "sha256-9JeQoP2qDo0EU+c8opdG490FLS4h56b54seSSAkVPqE=";
      };
      nodeModules = bunNodeModules {
        name = "opencode-mem-${version}-bun-deps";
        prod = false; # build needs typescript (devDep)
        srcPath = src;
        outputHash = "sha256-G9xbZaUfqBy3egbu+wzn0kv00e59wC8NTHZpV04Kv68=";
      };
      webNodeModules = bunNodeModules {
        name = "opencode-mem-${version}-web-bun-deps";
        prod = false;
        outputHash = "sha256-VNV2HvCejZnnAcCBBT3EDQNV4XZuHy5k2qtjS7E2zCc=";
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
        test -e $out/share/opencode-plugins/opencode-mem/dist/plugin.js || { echo "plugin entry missing: dist/plugin.js"; exit 1; }
      '';
  };
}
