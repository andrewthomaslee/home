{
  inputs,
  # self,
  lib,
  ...
}: {
  # ------ Home-manager Modules ------ #
  flake.homeModules.headroom = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.homeSpec.programs.headroom;

    py = pkgs.unstable.python313Packages;

    # Runtime deps for `headroom-ai[all]` (= proxy,code,ml,memory,relevance,
    # image,reports,otel,evals,voice,html,mcp,spreadsheet). All are available
    # in nixpkgs python313Packages, so we only build the headroom wheel itself
    # and propagate these pre-built dependencies.
    allDeps = with py; [
      # --- core ---
      tiktoken
      pydantic
      litellm
      click
      rich
      opentelemetry-api
      ast-grep-cli
      pyyaml
      tomlkit
      # --- proxy ---
      fastapi
      uvicorn
      orjson
      httpx
      openai
      mcp
      magika
      zstandard
      websockets
      onnxruntime
      transformers
      watchdog
      sqlite-vec
      # --- code (AST compression) ---
      # NOTE: nixpkgs ships tree-sitter-language-pack 1.4.x, while upstream pins
      # <1.0 due to a node-API change (.kind vs .type) that breaks the
      # CodeCompressor walker. Building proceeds (the wheel's declared version
      # constraints are not enforced by buildPythonApplication), but AST code
      # compression may misbehave at runtime. Non-code paths are unaffected.
      tree-sitter-language-pack
      tree-sitter
      # --- ml (Kompress) ---
      torch
      huggingface-hub
      # --- memory ---
      sentence-transformers
      # --- relevance ---
      fastembed
      numpy
      # --- image ---
      pillow
      sentencepiece
      rapidocr
      # --- reports ---
      jinja2
      # --- otel ---
      opentelemetry-sdk
      opentelemetry-exporter-otlp-proto-http
      # --- evals ---
      datasets
      scikit-learn
      anthropic
      # --- html ---
      trafilatura
      # --- mcp (server tools; shared with proxy) ---
      starlette
      # --- spreadsheet ---
      openpyxl
      xlrd
    ];

    # The flake input `headroom` is the prebuilt manylinux_2_28 x86_64 wheel
    # (cp310-abi3, compatible with CPython 3.10–3.13). Nix stores non-archive
    # URL inputs under the bare filename `source` (no `.whl` extension), which
    # breaks buildPythonApplication's `dist/*.whl` globs (wheelUnpackPhase,
    # pythonRuntimeDepsCheckHook, pypaInstallPhase). We re-materialize the wheel
    # under its real PyPI filename via runCommand — this also keeps the flake
    # input referenced, so the v0.36.5 pin in flake.lock is authoritative. Using
    # the wheel avoids rebuilding the maturin/Rust cdylib (headroom/_core.so)
    # from source; autoPatchelfHook rewires its DT_NEEDED entries to the nix store.
    headroom-wheel = pkgs.runCommand "headroom-ai-wheel" {} ''
      mkdir -p $out
      cp ${inputs.headroom} $out/headroom_ai-0.36.5-cp310-abi3-manylinux_2_28_x86_64.whl
    '';
    headroom-pkg = py.buildPythonApplication {
      pname = "headroom-ai";
      version = "0.36.5";
      format = "wheel";
      src = "${headroom-wheel}/headroom_ai-0.36.5-cp310-abi3-manylinux_2_28_x86_64.whl";
      nativeBuildInputs = [pkgs.autoPatchelfHook];
      # The Rust extension links against libstdc++/libgcc_s; stdenv.cc.cc.lib
      # provides them. ONNX Runtime and other optional native libs are
      # dlopen'd at runtime via the propagated python packages, not linked at
      # build time.
      buildInputs = [pkgs.stdenv.cc.cc.lib];
      propagatedBuildInputs = allDeps;
      # If autoPatchelf reports unresolved libs that are only dlopen'd at
      # runtime (e.g. libonnxruntime), ignore them rather than failing.
      autoPatchelfIgnoreMissingDeps = ["libonnxruntime.so"];
      meta = {
        description = "Context compression layer for AI agents (headroom wrap opencode)";
        homepage = "https://headroom-docs.vercel.app/docs";
        license = lib.licenses.asl20;
        mainProgram = "headroom";
        platforms = ["x86_64-linux"];
      };
    };
  in {
    options.homeSpec.programs.headroom = {
      enable = lib.mkEnableOption "headroom context compression layer";
      package = lib.mkOption {
        type = lib.types.package;
        default = headroom-pkg;
        defaultText = lib.literalExpression "headroom-ai 0.36.5 (prebuilt wheel)";
        description = ''
          The headroom-ai package to install. Defaults to the prebuilt
          manylinux_2_28 x86_64 wheel pinned as the `headroom` flake input,
          patched with autoPatchelf and propagated with the `[all]` runtime
          dependencies from nixpkgs python313Packages.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      home.packages = [cfg.package];
      # When opencode is also enabled, surface headroom on its PATH so a
      # wrapped session (`headroom wrap opencode`) can find the proxy launcher.
      # The `... or false` makes this a no-op when the opencode module isn't
      # loaded, so the headroom module has no hard dependency on opencode.
      # extraPackages is a list option that merges by concatenation.
      programs.opencode = lib.mkIf (config.programs.opencode.enable or false) {
        extraPackages = [cfg.package];
      };
    };
  };
}
