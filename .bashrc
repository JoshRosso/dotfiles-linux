PS1='\u (\e[38;5;198m\w\e[0m) [\e[38;5;148m$(git branch 2>/dev/null | grep '^*' | colrm 1 2)\e[0m]\n\$ '

# Environment / Path
export GOPATH=/home/josh/dev/go

# Load aliases
if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# History
# Don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth
# Append to the history file, don't overwrite it
shopt -s histappend
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000
