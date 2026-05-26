{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      isDirty = !(self ? rev);
      rawCommit = self.rev or self.dirtyRev or "unknown";
      commit = if isDirty then builtins.replaceStrings [ "-dirty" ] [ "" ] rawCommit else rawCommit;
      date = self.lastModifiedDate or "";
      ver = "0.1.0";
      modPath = "github.com/zebradil/znix/tools/znixctl/internal/version";
    in
    {
      packages.znixctl = pkgs.buildGoModule {
        pname = "znixctl";
        version = ver;
        src = "${self}/tools/znixctl";
        vendorHash = "sha256-mojEeWs3/lvD5LZw0fjyMnRfuq7vIVBxQ7QHv0XUZDs=";
        env.CGO_ENABLED = 0;
        ldflags = [
          "-s"
          "-w"
          "-X"
          "${modPath}.Version=${ver}"
          "-X"
          "${modPath}.Commit=${commit}"
          "-X"
          "${modPath}.Dirty=${if isDirty then "true" else "false"}"
          "-X"
          "${modPath}.Date=${date}"
        ];
        meta = {
          description = "znix multitool — operational scripts ported to Go";
          mainProgram = "znixctl";
        };
      };
    };
}
