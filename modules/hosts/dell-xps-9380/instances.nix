{ inputs, lib, ... }:
let
  system = "x86_64-linux";

  hosts = {
    d1 = {
      address = "192.168.0.111/24";
      fallback = "192.168.0.121/24";
      vpn = "100.104.120.72";
    };
    d2 = {
      address = "192.168.0.112/24";
      fallback = "192.168.0.122/24";
      vpn = "100.90.127.59";
    };
    d3 = {
      address = "192.168.0.113/24";
      fallback = "192.168.0.123/24";
      vpn = "100.122.248.98";
    };
  };
in
{
  flake = {
    modules.nixos = lib.mapAttrs (name: h: {
      imports = [ inputs.self.modules.nixos.dell-xps-9380 ];
      networking.hostName = name;
      znix.dualNet = {
        address = h.address;
        fallbackAddress = h.fallback;
      };
      znix.k3sNode = {
        selfLan = lib.removeSuffix "/24" h.address;
        selfVpn = h.vpn;
      };
    }) hosts;

    nixosConfigurations = lib.mergeAttrsList (
      lib.mapAttrsToList (name: _: inputs.self.lib.mkNixos system name { }) hosts
    );

    nixosSystemMap = lib.genAttrs (builtins.attrNames hosts) (_: system);
  };
}
