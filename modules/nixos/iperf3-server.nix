_: {
  flake.modules.nixos.iperf3-server = {
    services.iperf3 = {
      enable = true;
      openFirewall = true;
    };
  };
}
