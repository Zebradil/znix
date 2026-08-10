{ ... }:
{
  znix.workarounds.moonlight-qt = {
    systems = [ "aarch64-darwin" ];
    reason = ''ld64-957.1 SIGTRAPs ("Trace/BPT trap: 5") linking large Qt apps; link with LLVM lld instead.'';
    override = pkgs: old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.lld ];
      NIX_CFLAGS_LINK = (old.NIX_CFLAGS_LINK or "") + " -fuse-ld=lld";
    };
  };
}
