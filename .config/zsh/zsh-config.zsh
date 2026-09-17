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
