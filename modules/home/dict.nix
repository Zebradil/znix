_: {
  flake.modules.homeManager.dict =
    { lib, pkgs, ... }:
    let
      # dictd wants an explicit data/index pair per database; the filenames are
      # not uniform across packages (WordNet ships its .dict uncompressed, Mueller
      # ships five separate dictionaries), so they are spelled out rather than
      # globbed.
      databases = [
        {
          name = "mueller";
          package = pkgs.dictdDBs.mueller_eng2rus_pkg;
          stem = "mueller-base";
        }
        {
          name = "eng-rus";
          package = pkgs.dictdDBs.eng2rus;
          stem = "eng-rus";
        }
        {
          name = "wn";
          package = pkgs.dictdDBs.wordnet;
          stem = "wn";
          compressed = false;
        }
        {
          name = "eng-deu";
          package = pkgs.dictdDBs.eng2deu;
          stem = "eng-deu";
        }
        {
          name = "deu-eng";
          package = pkgs.dictdDBs.deu2eng;
          stem = "deu-eng";
        }
      ];

      entry =
        db:
        let
          base = "${db.package}/share/dictd/${db.stem}";
          data = if db.compressed or true then "${base}.dict.dz" else "${base}.dict";
        in
        ''database ${db.name} { data "${data}" index "${base}.index" }'';

      dictdConf = pkgs.writeText "dictd.conf" (lib.concatMapStringsSep "\n" entry databases);

      dictLookup = pkgs.writeShellApplication {
        name = "dict-lookup";
        runtimeInputs = with pkgs; [
          coreutils
          dict # provides the dictd binary
          gnugrep
          gnused
          perl
        ];
        text = builtins.readFile ./dict/dict-lookup;
      };

      # Each front-end fixes a set of databases: searching all of them at once
      # prints German for every English word looked up.
      lookupFor =
        name: dbs:
        pkgs.writeShellScriptBin name ''
          exec ${lib.getExe' dictLookup "dict-lookup"} ${dictdConf} "${dbs}" "$@"
        '';
    in
    {
      home.packages = [
        (lookupFor "def" "mueller eng-rus wn")
        (lookupFor "defde" "eng-deu deu-eng")
      ];
    };
}
