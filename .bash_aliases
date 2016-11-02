# Graphical applications
alias spotify='spotify &> /dev/null &'
alias chrome='google-chrome &> /dev/null &'
alias incogchrome='google-chrome --incognito &> /dev/null &'
alias slack='slack &> /dev/null &'

# Shortcuts
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias c='clear'
alias l='ls -l'
alias ll='ls -la'
alias xclipc='xclip -selection c'
alias xclipp='xclip -o'

# Functions
# Launch site in new tab on existing chrome session
site() {
    if [ -z "$1" ]
    then
        echo "Provide a site to launch"
    else
        google-chrome $1 &> /dev/null &
    fi
}

# Logout
bye() {
  # Ensure cmus is off when logging out
  if [ $(ps a | grep -c [c]mus) -gt "0" ]
  then
    cmus-remote -s
  fi
  i3lock -c 000000
}

# Decrypt and copy (dac)
dac() {
  if [ -f $1 ]
  then
    gpg -d $1 | xclipc
  else
    echo '~/.gitToken file not found.'
    exit 1
  fi
}

# Spin up GitHub-flavored markdown server with grip
# https://github.com/joeyespo/grip
gripserv() {
  GIT_TOKEN=$(gpg -d ~/.gitToken)
  grip --user joshrosso --pass $GIT_TOKEN &> /dev/null &
  # TODO: hack; having issuew with exporting. needs to be looked at
  unset GIT_TOKEN
}
