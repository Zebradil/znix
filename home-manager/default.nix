{
  gke-kubeconfiger,
  mac-app-util,
  nix-index-database,
  pkgs,
  user,
}: let
  xdgHome = "/Users/${user}";
  xdg = {
    enable = true;
    cacheHome = "${xdgHome}/.cache";
    configHome = "${xdgHome}/.config";
    dataHome = "${xdgHome}/.local/share";
    stateHome = "${xdgHome}/.local/state";
  };
in {
  imports = [
    mac-app-util.homeManagerModules.default
    nix-index-database.hmModules.nix-index
    ./modules/google-cloud-sdk.nix
    ./modules/neovim.nix
    ./modules/starship.nix
    ./modules/zoxide.nix
    ./modules/zsh.nix
  ];

  xdg = xdg;

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      (final: _prev: {
        gke-kubeconfiger = gke-kubeconfiger.defaultPackage.${final.system};
      })
    ];
  };

  home.packages = with pkgs; [
    # Desktop apps
    alacritty
    iterm2
    keepassxc
    skhd
    slack
    yabai
    youtube-music
    zoom-us
    #_1password-gui # doesn't work when installed outside of /Applications
    #firefox-bin    # 1password extensions doesn't work if FF is installed outside of /Applications
    # (github:bandithedoge/nixpkgs-firefox-darwin)

    # Desktop-CLI integrations
    terminal-notifier
    tridactyl-native

    # CLI apps
    bat
    btop
    delta
    k9s
    lazygit
    tailscale
    tmux
    translate-shell

    #CLI tools
    bashInteractive
    chezmoi
    coreutils
    curl
    direnv
    duf
    eza
    fd
    fzf
    gh
    ghorg
    git
    gke-kubeconfiger
    gnused
    go-task
    goreleaser
    inetutils
    jq
    just
    kubectl
    kubernetes-helm
    moreutils
    myks
    ncdu
    rage
    rancher
    ripgrep
    rsync
    skopeo
    terraform
    velero
    vendir
    watchexec
    wget
    yq-go
    ytt

    # languages
    go
    gofumpt

    cargo
    clippy
    rust-analyzer
    rustfmt

    # shell
    zsh-completions
  ];

  services.syncthing.enable = true;

  home.file = {
    "${xdgHome}/.local/bin" = {
      source = ./bin;
      recursive = true;
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf.enable = true;
  programs.nix-index.enable = true;

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "24.05";
}
