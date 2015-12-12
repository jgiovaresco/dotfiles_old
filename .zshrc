# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster"

# Uncomment to change how often before auto-updates occur? (in days)
export UPDATE_ZSH_DAYS=13

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
plugins=(git svn debian mvn npm vagrant docker docker-compose sudo extract gradle)

source $ZSH/oh-my-zsh.sh

# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{aliases,path,extra,exports,dockerfunc}; do
	[[ -r "$file" ]] && [[ -f "$file" ]] && source "$file"
done
unset file

# HubiC 
hubic_daemon
#HUBIC_STATE=`hubic status | grep State | sed "s/State: //g"`
#[[ $HUBIC_STATE == "NotConnected" ]] && hubic login --password_path=./.config/hubiC/.hubicpwd $HUBIC_USERNAME /hubiC

# Environment

# Vim
# Prevent ^S and ^Q doing XON/XOFF (mostly for Vim)
stty -ixon

# Activate Jenv
[ -f /home/julien/.jenv/version ] && eval "$(jenv init -)"

# Activate RVM
[ -f /home/julien/.rvm/scripts/rvm ] && source $HOME/.rvm/scripts/rvm

# added by travis gem
[ -f /home/julien/.travis/travis.sh ] && source /home/julien/.travis/travis.sh

# Activate NVM
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
