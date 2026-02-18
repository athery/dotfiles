# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Load private secrets if present
if [ -f "$HOME/.secrets/global.env" ]; then
  source "$HOME/.secrets/global.env"
fi

#theming
export BAT_THEME="Catppuccin Macchiato"
export FZF_DEFAULT_OPTS="--color=bg:#24273a,fg:#cad3f5,hl:#ed8796,fg+:#cad3f5,bg+:#363a4f,prompt:#c6a0f6,pointer:#f5a97f,marker:#a6da95,info:#c6a0f6,spinner:#f4dbd6,header:#f4dbd6,border:#5b6078"
export LS_COLORS="$(vivid generate catppuccin-macchiato)"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
alias s="source ~/.bashrc"
alias top="btop"
alias vi="nvim"
alias vim="nvim"
alias ll="ls -al"
# "de web www-data" par exemple
de() {
  docker exec -ti -u "$2" "$1" bash
}

# copy myfile.txt or ls | copy
copy() {
  if [ -t 0 ]; then
    # No stdin → expect a filename
    if [ -z "$1" ]; then
      echo "Usage: copy <file> OR pipe into copy"
      return 1
    fi
    wl-copy < "$1"
  else
    # Data is being piped in
    wl-copy
  fi
}

alias paste="wl-paste"

# git aliases
[ -f /usr/share/bash-completion/completions/git ] && source /usr/share/bash-completion/completions/git
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
