# ###
# # Functions
# # ###
is_mac_os() {
  [ -d "/Users" ]
}

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="spaceship"

# Uncomment to change how often before auto-updates occur? (in days)
export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

if is_mac_os; then
  # MacOS

  bindkey -e
  bindkey '^[[1;9C' forward-word
  bindkey '^[[1;9D' backward-word

  # Remove user@host prefix
  export DEFAULT_USER="jgiovaresco"

  # Autojump
  [[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh

  # Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
  plugins=(zsh-syntax-highlighting zsh-autosuggestions git brew vagrant docker docker-compose sudo extract gradle npm rvm bundler gem rails kubectl)

  autoload -U compinit && compinit
  autoload -U bashcompinit && bashcompinit

  PROG=bridge source /etc/bash_completion.d/bridge
else
  ## Linux
  plugins=(git debian vagrant docker docker-compose sudo extract gradle npm rvm bundler gem rails)

  # HubiC 
  hubic_daemon
fi

source $ZSH/oh-my-zsh.sh

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{aliases,path,extra,exports,dockerfunc,goconf}; do
  [[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done
unset file

setopt hist_expire_dups_first # when trimming history, lose oldest duplicates first
setopt hist_ignore_dups # Do not write events to history that are duplicates of previous events
setopt hist_ignore_space # remove command line from history list when first character on the line is a space
setopt hist_find_no_dups # When searching history don't display results already cycled through twice
setopt hist_reduce_blanks # Remove extra blanks from each command line being added to history

# Environment

# Vim
# Prevent ^S and ^Q doing XON/XOFF (mostly for Vim)
stty -ixon

# Activate Jenv
[ -f $HOME/.jenv/version ] && eval "$(jenv init -)"

# Activate RVM
[ -f $HOME/.rvm/scripts/rvm ] && source $HOME/.rvm/scripts/rvm

# added by travis gem
[ -f $HOME/.travis/travis.sh ] && source $HOME/.travis/travis.sh

# Activate NVM
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Direnv
eval "$(direnv hook zsh)"

export YVM_DIR=/usr/local/opt/yvm
[ -r $YVM_DIR/yvm.sh ] && . $YVM_DIR/yvm.sh
