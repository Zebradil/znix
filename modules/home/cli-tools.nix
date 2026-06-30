_: {
  flake.modules.homeManager.cli-tools =
    { pkgs, ... }:
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
        # oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits fails on Darwin
        (mise.overrideAttrs (_: {
          doCheck = false;
        }))
        moreutils
        myks
        ncdu
        nh
        nmap
        nodejs
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

        # Languages
        cue

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
