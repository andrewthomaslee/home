{...}: {
  hostSpec.services = {
    motd.sshMotd = builtins.readFile ./sshMotd.sh;
    intel.enable = true;
  };
}
