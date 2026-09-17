for _zf in ~/dotfiles/.config/zsh/*.zsh; do
    source "$_zf"
done
unset _zf
eval "$(atuin init zsh)"
