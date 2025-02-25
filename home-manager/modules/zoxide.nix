{ ... }:
{
  programs.zoxide.enable = true;
  programs.zsh.sessionVariables._ZO_FZF_OPTS = "+s --preview 'exa -l --group-directories-first -T -L5 --color=always --color-scale {2..} | head -200'";
}
