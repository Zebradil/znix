{lib, ...}: {
  programs.starship = {
    enable = true;
    settings = let
      ld = "⸤"; # ⁅ ᜶
      rd = "⸥"; # ⁆
    in {
      "$schema" = "https://starship.rs/config-schema.json";
      add_newline = true;
      format = lib.concatStrings [
        "$all"
        "$fill"
        "\${custom.docker_host}"
        "$kubernetes"
        "$time"
        "$line_break"
        "$jobs"
        "$battery"
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
      time.disabled = false;
      fill.symbol = " ";

      # Nerd Font Symbols
      # - custom
      shlvl.symbol = "";
      sudo.symbol = "";
      terraform.symbol = "";
      # - official preset
      aws.symbol = " ";
      buf.symbol = "";
      c.symbol = "";
      conda.symbol = "";
      crystal.symbol = "";
      dart.symbol = "";
      directory.read_only = " 󰌾";
      docker_context.symbol = "";
      elixir.symbol = "";
      elm.symbol = "";
      fennel.symbol = "";
      fossil_branch.symbol = "";
      git_branch.symbol = "";
      golang.symbol = "";
      guix_shell.symbol = "";
      haskell.symbol = "";
      haxe.symbol = "";
      hg_branch.symbol = "";
      hostname.ssh_symbol = "";
      java.symbol = "";
      julia.symbol = "";
      kotlin.symbol = "";
      lua.symbol = "";
      memory_usage.symbol = "󰍛";
      meson.symbol = "󰔷";
      nim.symbol = "󰆥";
      nix_shell.symbol = "";
      nodejs.symbol = "";
      ocaml.symbol = "";
      os.symbols = {
        AlmaLinux = "";
        Alpaquita = "";
        Alpine = "";
        Amazon = "";
        Android = "";
        Arch = "";
        Artix = "";
        CentOS = "";
        Debian = "";
        DragonFly = "";
        Emscripten = "";
        EndeavourOS = "";
        Fedora = "";
        FreeBSD = "";
        Garuda = "󰛓";
        Gentoo = "";
        HardenedBSD = "󰞌";
        Illumos = "󰈸";
        Kali = "";
        Linux = "";
        Mabox = "";
        Macos = "";
        Manjaro = "";
        Mariner = "";
        MidnightBSD = "";
        Mint = "";
        NetBSD = "";
        NixOS = "";
        OpenBSD = "󰈺";
        OracleLinux = "󰌷";
        Pop = "";
        Raspbian = "";
        RedHatEnterprise = "";
        Redhat = "";
        Redox = "󰀘";
        RockyLinux = "";
        SUSE = "";
        Solus = "󰠳";
        Ubuntu = "";
        Unknown = "";
        Void = "";
        Windows = "󰍲";
        openSUSE = "";
      };
      package.symbol = "󰏗";
      perl.symbol = "";
      php.symbol = "";
      pijul_channel.symbol = "";
      python.symbol = "";
      rlang.symbol = "󰟔";
      ruby.symbol = "";
      rust.symbol = "";
      scala.symbol = "";
      swift.symbol = "";
      zig.symbol = "";

      # No versions
      buf.format = "[${ld}$symbol${rd}]($style)";
      bun.format = "[${ld}$symbol${rd}]($style)";
      cmake.format = "[${ld}$symbol${rd}]($style)";
      cobol.format = "[${ld}$symbol${rd}]($style)";
      crystal.format = "[${ld}$symbol${rd}]($style)";
      cmd_duration.format = "[${ld}⏱ $duration${rd}]($style)";
      daml.format = "[${ld}$symbol${rd}]($style)";
      dart.format = "[${ld}$symbol${rd}]($style)";
      deno.format = "[${ld}$symbol${rd}]($style)";
      dotnet.format = "[${ld}$symbol${rd}]($style)";
      elixir.format = "[${ld}$symbol${rd}]($style)";
      elm.format = "[${ld}$symbol${rd}]($style)";
      erlang.format = "[${ld}$symbol${rd}]($style)";
      fennel.format = "[${ld}$symbol${rd}]($style)";
      git_branch.format = "[${ld}$symbol $branch(:$remote_branch)${rd}]($style)";
      git_status.format = "([${ld}$all_status$ahead_behind${rd}]($style))";
      gleam.format = "[${ld}$symbol${rd}]($style)";
      golang.format = "[${ld}$symbol${rd}]($style)";
      gradle.format = "[${ld}$symbol${rd}]($style)";
      haxe.format = "[${ld}$symbol${rd}]($style)";
      helm.format = "[${ld}$symbol${rd}]($style)";
      java.format = "[${ld}$symbol${rd}]($style)";
      julia.format = "[${ld}$symbol${rd}]($style)";
      kotlin.format = "[${ld}$symbol${rd}]($style)";
      lua.format = "[${ld}$symbol${rd}]($style)";
      meson.format = "[${ld}$symbol${rd}]($style)";
      nim.format = "[${ld}$symbol${rd}]($style)";
      nix_shell.format = "[${ld}$symbol $state( \($name\))${rd}]($style)";
      nodejs.format = "[${ld}$symbol${rd}]($style)";
      ocaml.format = "[${ld}$symbol( \($switch_indicator$switch_name\))${rd}]($style)";
      opa.format = "[${ld}$symbol${rd}]($style)";
      perl.format = "[${ld}$symbol${rd}]($style)";
      php.format = "[${ld}$symbol${rd}]($style)";
      pulumi.format = "[${ld}$symbol$stack${rd}]($style)";
      purescript.format = "[${ld}$symbol${rd}]($style)";
      python.format = "[${ld}$symbol${rd}]($style)";
      quarto.format = "[${ld}$symbol${rd}]($style)";
      raku.format = "[${ld}$symbol${rd}]($style)";
      red.format = "[${ld}$symbol${rd}]($style)";
      rlang.format = "[${ld}$symbol${rd}]($style)";
      ruby.format = "[${ld}$symbol${rd}]($style)";
      rust.format = "[${ld}$symbol${rd}]($style)";
      time.format = "[${ld}$time${rd}]($style)";
      solidity.format = "[${ld}$symbol${rd}]($style)";
      sudo.format = "[${ld}$symbol${rd}]($style)";
      swift.format = "[${ld}$symbol${rd}]($style)";
      terraform.format = "[${ld}$symbol( $workspace)${rd}]($style)";
      typst.format = "[${ld}$symbol${rd}]($style)";
      vagrant.format = "[${ld}$symbol${rd}]($style)";
      vlang.format = "[${ld}$symbol${rd}]($style)";
      zig.format = "[${ld}$symbol${rd}]($style)";
    };
  };
}
