{lib, ...}: {
  programs.starship = {
    enable = true;
    settings = {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;
      format = lib.concatStrings [
        "$all"
        "$fill"
        "\${custom.docker_host}"
        "$kubernetes"
        "$line_break"
        "$jobs"
        "$battery"
        "$time"
        "$status"
        "$container"
        "$os"
        "$shell"
        "$character"
      ];
      custom.docker_host = {
        symbol = " ";
        command = "docker info --format \"{{.Name}}\"";
        when = "[ ! -z $DOCKER_HOST ]";
        style = "blue bold";
        format = "[$symbol$output]($style)";
      };
      gcloud = {
        disabled = true;
        # Add project name
        format = "on [$symbol$account(@$domain)(\\($project\\))]($style) ";
      };
      kubernetes = {
        disabled = false;
        # Removed `in` in the end, because it's placed in the end of the line
        format = "[$symbol$context( \\($namespace\\))]($style)";
      };
      sudo.disabled = false;
      shlvl.disabled = false;
      fill.symbol = " ";

      # Nerd Font Symbols
      # - custom
      shlvl.symbol = " ";
      sudo.symbol = " ";
      terraform.symbol = " ";
      # - official preset
      aws.symbol = "  ";
      buf.symbol = " ";
      c.symbol = " ";
      conda.symbol = " ";
      crystal.symbol = " ";
      dart.symbol = " ";
      directory.read_only = " 󰌾";
      docker_context.symbol = " ";
      elixir.symbol = " ";
      elm.symbol = " ";
      fennel.symbol = " ";
      fossil_branch.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      guix_shell.symbol = " ";
      haskell.symbol = " ";
      haxe.symbol = " ";
      hg_branch.symbol = " ";
      hostname.ssh_symbol = " ";
      java.symbol = " ";
      julia.symbol = " ";
      kotlin.symbol = " ";
      lua.symbol = " ";
      memory_usage.symbol = "󰍛 ";
      meson.symbol = "󰔷 ";
      nim.symbol = "󰆥 ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      ocaml.symbol = " ";
      os.symbols = {
        AlmaLinux = " ";
        Alpaquita = " ";
        Alpine = " ";
        Amazon = " ";
        Android = " ";
        Arch = " ";
        Artix = " ";
        CentOS = " ";
        Debian = " ";
        DragonFly = " ";
        Emscripten = " ";
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Garuda = "󰛓 ";
        Gentoo = " ";
        HardenedBSD = "󰞌 ";
        Illumos = "󰈸 ";
        Kali = " ";
        Linux = " ";
        Mabox = " ";
        Macos = " ";
        Manjaro = " ";
        Mariner = " ";
        MidnightBSD = " ";
        Mint = " ";
        NetBSD = " ";
        NixOS = " ";
        OpenBSD = "󰈺 ";
        OracleLinux = "󰌷 ";
        Pop = " ";
        Raspbian = " ";
        RedHatEnterprise = " ";
        Redhat = " ";
        Redox = "󰀘 ";
        RockyLinux = " ";
        SUSE = " ";
        Solus = "󰠳 ";
        Ubuntu = " ";
        Unknown = " ";
        Void = " ";
        Windows = "󰍲 ";
        openSUSE = " ";
      };
      package.symbol = "󰏗 ";
      perl.symbol = " ";
      php.symbol = " ";
      pijul_channel.symbol = " ";
      python.symbol = " ";
      rlang.symbol = "󰟔 ";
      ruby.symbol = " ";
      rust.symbol = " ";
      scala.symbol = " ";
      swift.symbol = " ";
      zig.symbol = " ";

      # No versions
      buf.format = "[$symbol]($style)";
      bun.format = "[$symbol]($style)";
      cmake.format = "[$symbol]($style)";
      cobol.format = "[$symbol]($style)";
      crystal.format = "[$symbol]($style)";
      daml.format = "[$symbol]($style)";
      dart.format = "[$symbol]($style)";
      deno.format = "[$symbol]($style)";
      dotnet.format = "[$symbol]($style)";
      elixir.format = "[$symbol]($style)";
      elm.format = "[$symbol]($style)";
      erlang.format = "[$symbol]($style)";
      fennel.format = "[$symbol]($style)";
      gleam.format = "[$symbol]($style)";
      golang.format = "[$symbol]($style)";
      gradle.format = "[$symbol]($style)";
      haxe.format = "[$symbol]($style)";
      helm.format = "[$symbol]($style)";
      java.format = "[$symbol]($style)";
      julia.format = "[$symbol]($style)";
      kotlin.format = "[$symbol]($style)";
      lua.format = "[$symbol]($style)";
      meson.format = "[$symbol]($style)";
      nim.format = "[$symbol]($style)";
      nodejs.format = "[$symbol]($style)";
      ocaml.format = "[$symbol(\($switch_indicator$switch_name\) )]($style)";
      opa.format = "[$symbol]($style)";
      perl.format = "[$symbol]($style)";
      php.format = "[$symbol]($style)";
      pulumi.format = "[$symbol$stack]($style)";
      purescript.format = "[$symbol]($style)";
      python.format = "[$symbol]($style)";
      quarto.format = "[$symbol]($style)";
      raku.format = "[$symbol]($style)";
      red.format = "[$symbol]($style)";
      rlang.format = "[$symbol]($style)";
      ruby.format = "[$symbol]($style)";
      rust.format = "[$symbol]($style)";
      solidity.format = "[$symbol]($style)";
      swift.format = "[$symbol]($style)";
      typst.format = "[$symbol]($style)";
      vagrant.format = "[$symbol]($style)";
      vlang.format = "[$symbol]($style)";
      zig.format = "[$symbol]($style)";
    };
  };
}
