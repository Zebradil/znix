{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.znixctl = pkgs.buildGoModule {
        pname = "znixctl";
        version = "0.1.0";
        src = "${self}/tools/znixctl";
        vendorHash = "sha256-mojEeWs3/lvD5LZw0fjyMnRfuq7vIVBxQ7QHv0XUZDs=";
        env.CGO_ENABLED = 0;
        ldflags = [
          "-s"
          "-w"
        ];
        meta = {
          description = "znix multitool — operational scripts ported to Go";
          mainProgram = "znixctl";
        };
      };
    };
}
