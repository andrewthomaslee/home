{inputs, ...}: {
  imports = with inputs.packer.nixosModules; [
    default
    hcloud
    ext4
  ];
  config = {
    # hostSpec options
    hostSpec = {};
  };
}
