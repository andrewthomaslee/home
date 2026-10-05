_: {
  # Local OpenShell gateway (VM/libkrun compute driver); the netsa user's
  # openshell picks it up automatically via the module's home-manager
  # sharedModules injection (profile enables homeSpec.programs.openshell).
  # See flake-parts/nixosModules/openshell-gateway.nix and
  # documentation/docs/openshell/.
  hostSpec.services.openshell.gateway.enable = true;
}
