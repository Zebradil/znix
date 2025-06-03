{
  gke-kubeconfiger,
  nix-index-database,
  pkgs,
  user,
}:
let
  xdgHome = if pkgs.stdenv.isDarwin then "/Users/${user}" else "/home/${user}";
in
{
  imports = [
    nix-index-database.hmModules.nix-index
    ./modules/google-cloud-sdk.nix
    ./modules/neovim.nix
    ./modules/starship.nix
    ./modules/zoxide.nix
    ./modules/zsh.nix
  ];

  home.username = user;
  home.homeDirectory = xdgHome;

  xdg = {
    enable = true;
    cacheHome = "${xdgHome}/.cache";
    configHome = "${xdgHome}/.config";
    dataHome = "${xdgHome}/.local/share";
    stateHome = "${xdgHome}/.local/state";
  };

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
    keepassxc
    slack
    youtube-music
    zoom-us

    # Desktop-CLI integrations
    tridactyl-native

    # CLI apps
    bat
    btop
    delta
    htop
    k9s
    lazygit
    tailscale
    tmux
    translate-shell

    #CLI tools
    bashInteractive
    coreutils
    curl
    direnv
    duf
    eza
    fd
    formatjson5
    fzf
    gh
    ghorg
    git
    gke-kubeconfiger
    gnumake
    gnused
    go-task
    goreleaser
    home-manager
    inetutils
    ipcalc
    jq
    just
    krew
    kubectl
    kubernetes-helm
    moreutils
    myks
    nmap
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
