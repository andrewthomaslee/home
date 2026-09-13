{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    # The upstream tag's package.json still says "version": "1.0.0"; report
    # the real tag so `artifacthub-mcp --version`-style introspection and
    # the store path name match the pin in flake.nix.
    version = "1.1.1";
  in {
    packages.artifacthub-mcp = pkgs.buildNpmPackage {
      pname = "artifacthub-mcp";
      inherit version;
      src = inputs.artifacthub-mcp;

      npmDepsHash = "sha256-/hOUQOMpCux/Dt1ZUqqZUIGjIZJkp8g9a0Pqd7bMlVA=";

      # package.json has no build script wired for nix; tsc -> dist/ via the
      # "build" script is all that is needed (pure TS, no native modules).
      npmBuild = "npm run build";

      # Default npmInstallHook: tsc-produced dist/ plus the hermetic
      # node_modules are installed to $out/lib/node_modules/artifacthub-mcp;
      # ESM resolves its deps from there. Upstream package.json has no `bin`
      # field, so wrap the entrypoint manually.
      dontNpmPrune = true;
      postInstall = ''
        mkdir -p $out/bin
        makeWrapper ${pkgs.nodejs}/bin/node $out/bin/artifacthub-mcp \
          --add-flags "$out/lib/node_modules/artifacthub-mcp/dist/index.js"
      '';

      meta = {
        description = "MCP server for Artifact Hub (Helm charts)";
        homepage = "https://github.com/AlexW00/artifacthub-mcp";
        license = pkgs.lib.licenses.mit;
        mainProgram = "artifacthub-mcp";
        platforms = ["x86_64-linux"];
      };
    };
  };
}
