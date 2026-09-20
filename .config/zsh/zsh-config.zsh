# Record timestamps and elapsed time per command.
# INC_APPEND_HISTORY_TIME writes each entry after it finishes (so elapsed is
# accurate) and is mutually exclusive with SHARE_HISTORY (set by oh-my-zsh).
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY_TIME
unsetopt SHARE_HISTORY
HISTSIZE=500000
SAVEHIST=500000

alias zc="zshcfgsrc"
alias zshpwd="echo ~/dotfiles/.config/zsh"
alias zshcopy='cat ~/dotfiles/.config/zsh/*.zsh | wl-copy'
alias sourcezsh='source ~/dotfiles/.zshrc'
alias zshconfig='nvim ~/dotfiles/.config/zsh/*.zsh'
alias szsh="sourcezsh"
alias sz="sourcezsh"

zshcfgsrc() {
  if [[ "$1" == "-k" ]]; then
    kate ~/dotfiles/.config/zsh/*.zsh
  else
    # each file opens in its own buffer; :bn / :bp to switch
    nvim ~/dotfiles/.config/zsh/*.zsh
  fi
  source ~/dotfiles/.zshrc
}
