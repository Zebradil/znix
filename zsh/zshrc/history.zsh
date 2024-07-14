# +=========================+
# | History Configuration   |
# +-------------------------+

HISTSIZE=10000          #How many lines of history to keep in memory
HISTFILE=~/.zsh_history #Where to save history to disk
SAVEHIST=10000          #Number of history entries to save to disk
HISTDUP=erase           #Erase duplicates in the history file
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt appendhistory    #Append history to the history file (no overwriting)
setopt sharehistory     #Share history across terminals
setopt incappendhistory #Immediately append to the history file, not just when a term is killed
