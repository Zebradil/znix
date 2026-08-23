_: {
  flake.modules.homeManager.translate =
    { pkgs, ... }:
    {
      home.packages = [
        # mozhi itself, for the engine comparison `mozhi translate -e all` gives.
        pkgs.mozhi
        (pkgs.writeShellApplication {
          name = "tl";
          runtimeInputs = with pkgs; [
            jq
            mozhi
          ];
          text = builtins.readFile ./translate/tl;
        })
      ];
    };
}
