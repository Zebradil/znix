_: {
  flake.modules.homeManager.cli-tools =
    { pkgs, ... }:
    let
      ghRenovateTriage = pkgs.writeShellApplication {
        name = "gh-renovate-triage";
        runtimeInputs = with pkgs; [
          coreutils
          gh
          gnugrep
          jq
        ];
        text = builtins.readFile ./cli-tools/gh-renovate-triage;
      };
      ghPrUnresolvedComments = pkgs.writeShellApplication {
        name = "gh-pr-unresolved-comments";
        runtimeInputs = with pkgs; [
          coreutils
          gh
          jq
        ];
        text = builtins.readFile ./cli-tools/gh-pr-unresolved-comments;
      };
    in
    {
      home.packages = with pkgs; [
        # Desktop apps
        alacritty
        keepassxc

        # Desktop-CLI integrations
        tridactyl-native

        # CLI apps
        bat
        broot
        delta
        difftastic
        htop
        jnv
        k9s
        lazygit
        tmux
        translate-shell

        # CLI tools
        ghRenovateTriage
        ghPrUnresolvedComments
        bashInteractive
        comma
        coreutils
        curl
        dive
        duf
        eza
        fd
        formatjson5
        gh
        ghorg
        git
        gnumake
        gnused
        go-task
        goreleaser
        inetutils
        ipcalc
        jq
        just
        krew
        kubectl
        kubernetes-helm
        moreutils
        myks
        ncdu
        nh
        nix-diff
        nmap
        nodejs
        nvd
        pciutils
        rage
        rancher
        repgrep
        ripgrep
        rsync
        sd
        skopeo
        sops
        stern
        terraform
        usbutils
        vals
        velero
        vendir
        watchexec
        wget
        yq-go
        yt-dlp
        ytt

        # Notshoot
        doggo
        ldns # provides drill
        bind # provides dig, host and nslookup

        # Languages
        cue

        jsonnet

        pkl

        go
        go-tools
        gofumpt
        golangci-lint
        gopls

        kcl
        (kcl-language-server.overrideAttrs (old: {
          meta = old.meta // {
            platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
          };
        }))

        nil
        nixd
        nixfmt
        nixfmt-tree

        python3

        rustup

        uv

        # Shell
        zsh-completions
      ];
    };
}
