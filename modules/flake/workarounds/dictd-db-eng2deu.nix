{ ... }:
{
  znix.workarounds.dictd-db-eng2deu = {
    package = "dictdDBs.eng2deu";
    systems = [ "aarch64-darwin" ];
    reason = "dictdDBs.eng2deu is a data-only package but claims meta.platforms = linux, so it refuses to evaluate on Darwin.";
    override = _pkgs: old: {
      meta = old.meta // {
        platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
      };
    };
  };
}
