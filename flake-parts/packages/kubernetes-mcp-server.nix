{lib, ...}: {
  perSystem = {pkgs, ...}: {
    # containers/kubernetes-mcp-server — MCP server for Kubernetes and
    # OpenShift (kubectl + helm toolsets, stdio transport). Hermetic Go
    # build from the pinned upstream tag; no npx/docker at runtime.
    packages.kubernetes-mcp-server = pkgs.buildGoModule {
      pname = "kubernetes-mcp-server";
      version = "0.0.66";

      src = pkgs.fetchFromGitHub {
        owner = "containers";
        repo = "kubernetes-mcp-server";
        rev = "v0.0.66";
        hash = "sha256-vnJxSCfnpvOZJXQpKrCAW4QKt5R2PJDYQevA7O1uXZg=";
      };

      vendorHash = "sha256-gbqoT4X+wVOEktHm7jaAH9vHrUBrYgR8OjyFz1ljP6k=";

      env.CGO_ENABLED = "0";

      # Unit tests require a live cluster / env setup; validated via --help
      # gate instead.
      doCheck = false;

      ldflags = [
        "-s"
        "-w"
        "-X github.com/containers/kubernetes-mcp-server/pkg/version.Version=0.0.66"
      ];

      meta = {
        description = "MCP server for Kubernetes and OpenShift";
        homepage = "https://github.com/containers/kubernetes-mcp-server";
        license = lib.licenses.asl20;
        mainProgram = "kubernetes-mcp-server";
        platforms = ["x86_64-linux"];
      };
    };
  };
}
