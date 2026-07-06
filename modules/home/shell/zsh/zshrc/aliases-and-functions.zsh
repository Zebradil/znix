# +=========================+
# | Aliases and functions   |
# +-------------------------+

log::debug "Loading aliases and functions"

z:prefix-lines() {
  local prefix="${1:?specify prefix}"
  while read -r line; do
    echo "$prefix$line"
  done
}

z:diff:yaml() {
  delta <(yq -P 'sort_keys(..)' "$1") <(yq -P 'sort_keys(..)' "$2")
}

z:delete-host() {
  local line="${1:?specify line number}"
  sed -i "${line}d" ~/.ssh/known_hosts
}

insist() {
  local delay=1
  local cmd
  cmd="$(fc -ln | tail -1)"
  log::info "Insisting on: $cmd"
  until eval "$cmd"; do
    sleep "$delay"
  done
}

alias tmpcd='cd "$(mktemp -d)"'
mcd() {
  if [ -d "$1" ]; then
    log::info "$1 exists"
  else
    mkdir -p "$1"
    log::info "$1 created"
  fi
  cd "$1" || exit
}

# To use `sudo` with aliases
alias sudo='sudo '

alias lsblk+='lsblk -o "NAME,MAJ:MIN,RM,SIZE,RO,FSTYPE,MOUNTPOINT,UUID"'

if lib::check_commands exa; then
  alias ls='exa'
  alias l='ls -l --group-directories-first --git' # --color-scale (has issues on white background)
  alias la='l -a'
  alias lt='la -s newest'
fi

if lib::check_commands bat; then
  alias cat='bat'
  alias caty='bat -lyaml'
fi

if lib::check_commands openstack acme.sh yq; then
  my:openstack:acme.sh() {
    env $(
      yq eval --output-format props \
        '.clouds[env(OS_CLOUD)] | explode(.) | (with_entries(select(.key != "auth")), .auth)' \
        ~/.config/openstack/clouds.yaml \
        | sed -r 's/^(\w+) = (.*)/\UOS_\1\E=\2/' \
        | xargs -d '\n'
    ) \
      acme.sh --issue --dns dns_openstack --domain "${@}"
  }
fi

if lib::check_commands rsync; then
  alias cp="rsync --archive --human-readable --partial --progress"
fi

if lib::check_commands trans; then
  alias tru='trans -j en:ru'
  alias ten='trans -j ru:en'
  alias пер='trans -j ru:en'

  alias truen='trans -j ru:en'
  alias tenru='trans -j en:ru'

  alias tende='trans -j en:de'
  alias tdeen='trans -j de:en'

  alias trude='trans -j ru:de'
  alias tderu='trans -j de:ru'
fi

if lib::check_commands timew; then
  alias tt='timew'
fi

if lib::check_commands curl; then
  alias wanip='curl -s https://ipinfo.io/ip'
fi

if lib::check_commands ffmpeg; then
  alias ffprobe='ffprobe -hide_banner'
  alias ffmpeg='ffmpeg -hide_banner'
fi

if [[ ! ${commands[pbcopy]} ]]; then
  alias pbcopy="xclip -selection c"
  alias pbpaste="xclip -selection clipboard -o"
fi

if lib::check_commands fzf rg bat; then
  function frg() (
    rg --line-number --color=always "$@" \
      | fzf --exit-0 -d ':' --ansi --no-sort --preview-window 'up,70%,+{2}/2' \
        --preview 'bat --terminal-width=$FZF_PREVIEW_COLUMNS --style=numbers --color=always --highlight-line {2} {1}' \
        --bind "ctrl-o:become($EDITOR +{2} {1})"
  )

  function frgn() (
    IFS=: found=($(frg "$@"))
    $EDITOR "${found[1]}" "+${found[2]}"
  )
fi

if lib::check_commands alacritty-colorscheme fzf exa bat; then
  function chct() (
    local alclr=alacritty-colorscheme
    $alclr list \
      | fzf "$@" --preview "
        $alclr apply {}
        bat --color=always --plain --line-range 52:68 ~/.zshrc
        echo
    exa -l /tmp"
  )
fi

if lib::check_commands fzf fd; then
  # Use fd and fzf to get the args to a command.
  # Works only with zsh
  # Examples:
  # f mv # To move files. You can write the destination after selecting the files.
  # f 'echo Selected:'
  # f 'echo Selected music:' --extention mp3
  # fm rm # To rm files in current directory
  f() {
    sels=("${(@f)$(fd "${fd_default[@]}" "${@:2}" | fzf)}")
    test -n "$sels" && print -z -- "$1 ${sels[@]:q:q}"
  }

  # Like f, but not recursive.
  fm() { f "$@" --max-depth 1; }
fi

if lib::check_commands fzf git; then
  # Checkout git branch/tag, with a preview showing the commits between the tag/branch and HEAD
  my:git:fzf-checkout() {
    local tags branches target
    branches=$(
      git --no-pager branch --all \
        --format="%(if)%(HEAD)%(then)%(else)%(if:equals=HEAD)%(refname:strip=3)%(then)%(else)%1B[0;34;1mbranch%09%1B[m%(refname:short)%(end)%(end)" \
        | sed '/^$/d'
    ) || return
    tags=$(
      git --no-pager tag | awk '{print "\x1b[35;1mtag\x1b[m\t" $1}'
    ) || return
    target=$(
      (
        echo "$branches"
        echo "$tags"
      ) \
        | fzf --no-hscroll --no-multi -n 2 \
          --ansi --preview="git --no-pager log -150 --pretty=format:%s '..{2}'"
    ) || return
    git checkout $(awk '{print $2}' <<<"$target")
  }
fi

# SSH through a reusable proxy pod in the k8s cluster (sometimes a better route
# to a host). The pod self-expires after 30min with no active connection.
kssh() {
  if [[ -z "$1" ]]; then
    echo "Usage: kssh <ssh-host> [ssh-args...]"
    return 1
  fi
  lib::check_commands kubectl || return 1

  local ns="${KSSH_NAMESPACE:-default}"
  local pod="${KSSH_POD_NAME:-ssh-proxy-$USER}"
  local phase
  phase="$(kubectl -n "$ns" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null)"

  if [[ "$phase" != "Running" ]]; then
    # Clear a stale pod (Completed/Failed/Pending) before recreating.
    [[ -n "$phase" ]] && kubectl -n "$ns" delete pod "$pod" --now >/dev/null 2>&1
    log::info "Starting ssh proxy pod $pod"
    # Idle loop: exit after 30min with no live nc (i.e. no ssh session).
    kubectl -n "$ns" run "$pod" --image=alpine --restart=Never -- \
      sh -c 'idle=0; while [ $idle -lt 1800 ]; do if pgrep nc >/dev/null; then idle=0; else idle=$((idle+30)); fi; sleep 30; done' \
      >/dev/null || return 1
    kubectl -n "$ns" wait --for=condition=Ready "pod/$pod" --timeout=60s >/dev/null || return 1
  else
    log::debug "Reusing ssh proxy pod $pod"
  fi

  ssh -o ProxyCommand="kubectl -n $ns exec -i $pod -- nc %h %p" "$@"
}

kssh-clean() {
  kubectl -n "${KSSH_NAMESPACE:-default}" delete pod "${KSSH_POD_NAME:-ssh-proxy-$USER}" --now
}

# Deprecated aliases
#alias gmerge='( read branch && git pull && git merge origin/$branch -m "Merge $branch → $(git symbolic-ref --short -q HEAD)" && git push ) <<<'
#alias gship='( read branch && gmerge $branch && git push origin :$branch ) <<<'
#alias cpdiff='git diff --color | iconv -f cp1251 -t utf8 | less -r'
