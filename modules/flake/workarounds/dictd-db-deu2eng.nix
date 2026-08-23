{ ... }:
{
  znix.workarounds.dictd-db-deu2eng = {
    package = "dictdDBs.deu2eng";
    systems = [ "aarch64-darwin" ];
    reason = "dictdDBs.deu2eng is a data-only package but claims meta.platforms = linux, so it refuses to evaluate on Darwin.";
    override = _pkgs: old: {
      meta = old.meta // {
        platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
      };
    };
  };
}
