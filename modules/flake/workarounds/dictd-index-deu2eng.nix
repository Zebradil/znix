_: {
  workarounds.dictd-index-deu2eng = {
    package = "dictdDBs.deu2eng";
    reason = "The deu-eng.index that dictdDBs.deu2eng ships is not sorted in dictd's collation, so its binary search misses exact lookups at random.";
    # German headwords carry umlauts; without --utf8 they sort to the wrong place.
    override = pkgs: old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.dict ];
      postFixup = (old.postFixup or "") + ''
        dictfmt -I --utf8 < $out/share/dictd/deu-eng.index > "$TMPDIR/deu-eng.index"
        mv "$TMPDIR/deu-eng.index" $out/share/dictd/deu-eng.index
      '';
    };
    fixed =
      pkgs:
      let
        index = "${pkgs.dictdDBs.deu2eng}/share/dictd/deu-eng.index";
      in
      pkgs.runCommand "dictd-index-deu2eng-sorted" { nativeBuildInputs = [ pkgs.dict ]; } ''
        dictfmt -I --utf8 < ${index} > sorted
        # Compare entry order by (offset, length). dictfmt blanks headwords it
        # cannot encode, which moves them to the top, so those are left out.
        awk -F'\t' 'NR == FNR { if ($1 == "") bad[$2 FS $3] = 1; next } !(($2 FS $3) in bad) { print $2, $3 }' \
          sorted ${index} > upstream-order
        awk -F'\t' '$1 != "" { print $2, $3 }' sorted > dictd-order
        cmp -s upstream-order dictd-order
        touch $out
      '';
  };
}
