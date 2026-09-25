{lib}: {
  # Repo-bound helpers — pre-bound to THIS repo's root. Consumed as
  # customLib.relativeToRoot (see flake-parts/default.nix, which imports
  # this file via lib.extend).
  relativeToRoot = lib.path.append ../.;

  # Factory for consumers OUTSIDE this repo (exported as flake.lib, see
  # flake-parts/default.nix): bind the helpers to any root, then use the
  # result as a normal attribute set.
  #
  #   # another flake:
  #   (inputs.home.lib.mkLib ./.).relativeToRoot "src"
  #   # or, keeping nixpkgs' lib reachable too:
  #   (inputs.home.lib.mkLib ./.) // {inherit lib;}
  mkLib = root: {
    relativeToRoot = lib.path.append root;
  };
}
