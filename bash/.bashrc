# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
alias s="source ~/.bashrc"
alias top="btop"
alias vi="nvim"
alias vim="nvim"

# git aliases
alias ga="git add"
__git_complete ga _git_add
alias gaa="git add -A"
alias gb="git branch"
alias gci="git commit"
__git_complete gc _git_commit
alias gc="git checkout"
__git_complete gco _git_checkout
alias gd="git -c diff.external=difft diff"
alias gpl="git pull"
__git_complete gm _git_pull
alias gp="git push"
__git_complete gp _git_push
alias gst="git status"
__git_complete gs _git_status
alias gl="git log"
__git_complete gl _git_log
alias lg="lazygit"
alias lz="lazygit"
