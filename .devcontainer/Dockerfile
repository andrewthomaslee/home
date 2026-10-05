# Generic devenv toolchain image for the human dev container.
#
# Nothing from the worktree is baked in: the editor bind-mounts the repo,
# and agents clone at runtime. So .env / .secrets / .baton-pass never enter
# a container image. The devenv base image ships the devenv CLI, Nix and
# direnv, so there is no Nix bootstrap here.
FROM ghcr.io/cachix/devenv/devcontainer:latest

# Native devenv auto-activation (same hook the machines use via
# flake-parts/homeModules/devenv.nix). `devenv allow` from
# postCreateCommand trusts the mounted workspace.
RUN echo 'eval "$(devenv hook bash)"' >> ~/.bashrc

CMD ["sleep", "infinity"]