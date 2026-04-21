{...}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    # Check Files exist in the repo
    files.files = [
      {
        path_ = ".github/workflows/nix-flake-check.yml";
        drv = self'.packages.nix-flake-check;
      }
      {
        path_ = ".github/workflows/flakehub-publish.yml";
        drv = self'.packages.flakehub-publish;
      }
    ];

    # Pakcages that generate files to be checked into the repo
    packages = {
      nix-flake-check = pkgs.writers.writeYAML "nix-flake-check.yml" {
        on.push = {};
        jobs.check = {
          runs-on = "ubuntu-latest";
          steps = [
            {uses = "actions/checkout@v4";}
            {uses = "DeterminateSystems/nix-installer-action@main";}
            {uses = "DeterminateSystems/magic-nix-cache-action@main";}
            {run = "nix flake check --show-trace --all-systems --impure";}
          ];
        };
      };
      flakehub-publish = pkgs.writers.writeYAML "flakehub-publish.yml" {
        name = "Publish to FlakeHub";
        on = {
          push.tags = ["v?[0-9]+.[0-9]+.[0-9]+*"];
          workflow_dispatch.inputs.tag = {
            description = "The existing tag to publish to FlakeHub";
            type = "string";
            required = true;
          };
        };
        jobs.flakehub-publish = {
          runs-on = "ubuntu-latest";
          permissions = {
            id-token = "write";
            contents = "read";
          };
          steps = [
            {
              uses = "actions/checkout@v6";
              "with" = {
                persist-credentials = false;
                ref = "\${{ (inputs.tag != null) && format('refs/tags/{0}', inputs.tag) || '' }}";
              };
            }
            {uses = "DeterminateSystems/determinate-nix-action@v3";}
            {
              uses = "DeterminateSystems/flakehub-push@main";
              "with" = {
                visibility = "public";
                name = "andrewthomaslee/home";
                tag = "\${{ inputs.tag }}";
                include-output-paths = true;
              };
            }
          ];
        };
      };
    };
  };
}
