# +==========================+
# | Fuzzy finder             |
# +--------------------------+

if lib::check_commands fzf fd bat exa; then
  log::debug "Configuring fzf"

  source /usr/share/fzf/completion.zsh
  source /usr/share/fzf/key-bindings.zsh

  export FZF_DEFAULT_OPTS='--multi --no-height --extended'
  export FZF_DEFAULT_COMMAND='fd --no-ignore --strip-cwd-prefix --hidden --exclude .git --exclude node_modules --exclude "$HOME/go"'
  export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
  # TODO transform these commands to functions
  FZF_PREVIEW_MAX_LINES=200
  FZF_DIRECTORY_PREVIEW_CMD="exa -l --group-directories-first -T -L5 --color=always --color-scale {} | head -${FZF_PREVIEW_MAX_LINES}"
  FZF_TEXT_FILE_PREVIEW_CMD="bat -pp --italic-text=always --color=always -r:${FZF_PREVIEW_MAX_LINES}"
  export FZF_ALT_C_OPTS="--preview '${FZF_DIRECTORY_PREVIEW_CMD}'"

  # Use fd (https://github.com/sharkdp/fd) instead of the default find
  # command for listing path candidates.
  # - The first argument to the function ($1) is the base path to start traversal
  # - See the source code (completion.{bash,zsh}) for the details.
  _fzf_compgen_path() {
    local dir
    [[ $1 != . ]] && dir="$1"
    eval "${FZF_CTRL_T_COMMAND}" --follow . "$dir"
  }

  # Use fd to generate the list for directory completion
  _fzf_compgen_dir() {
    local dir
    [[ $1 != . ]] && dir="$1"
    eval "${FZF_CTRL_T_COMMAND}" --follow --type d . "$dir"
  }

  # (EXPERIMENTAL) Advanced customization of fzf options via _fzf_comprun function
  # - The first argument to the function is the name of the command.
  # - You should make sure to pass the rest of the arguments to fzf.
  _fzf_comprun() {
    local command=$1
    shift

    case "$command" in
    cd) fzf "$@" --preview "${FZF_DIRECTORY_PREVIEW_CMD}" ;;
    export | unset) fzf "$@" --preview "eval 'echo \$'{}" ;;
    ssh) fzf "$@" --preview 'dig {}' ;;
    man) man -k . | fzf --prompt='Man> ' --preview 'man $(echo {} | awk "{print \$1}") | '"${FZF_TEXT_FILE_PREVIEW_CMD} -lman" | awk '{print $1}' ;;
    vi | vim | nvim | nv) fzf "$@" --preview "[ -f {} ] && ${FZF_TEXT_FILE_PREVIEW_CMD} {} || ${FZF_DIRECTORY_PREVIEW_CMD}" ;;
    pacman) pacman -Qq | fzf --preview 'pacman -Qi {}' ;;
    *) fzf "$@" ;;
    esac
  }

  fzf-find-command-widget() {
    # TODO Add aliases and maybe builtins and functions
    LBUFFER=$(printf '%s\n' "${commands[@]}" \
      | fzf --preview '
        set -o pipefail
        cmd=$(basename {})
        pacman --color=always -Qo {}
        ( man $cmd | '"${FZF_TEXT_FILE_PREVIEW_CMD} -lman"' ) \
        || (
          set -e
          pkg=$(pacman -Qoq {} 2>/dev/null)
          pacman -Qi ${pkg} | rg "Description\s+:\s*(.*)" --only-matching --replace="\$1"
        )')
    zle redisplay
  }

  zle -N fzf-find-command-widget
  bindkey '\ex' fzf-find-command-widget

fi
