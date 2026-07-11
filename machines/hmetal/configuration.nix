{...}: {
  hostSpec = {
    networking.lan = {
      defaultGateway = "95.216.11.65";
      defaultGateway6 = "fe80::1";
    };
  };
}
