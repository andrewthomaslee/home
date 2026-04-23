{...}: {
  services.qemuGuest.enable = true;

  networking = let
    interface = "enp1s0";
  in {
    defaultGateway6 = {
      address = "fe80::1";
      inherit interface;
    };
    interfaces.${interface} = {
      useDHCP = true;
      ipv6.addresses = [
        {
          address = "2a01:4f9:c014:9b2::1";
          prefixLength = 64;
        }
      ];
    };
  };
}
