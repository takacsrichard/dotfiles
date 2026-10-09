# Record timestamps and elapsed time per command.
# INC_APPEND_HISTORY_TIME writes each entry after it finishes (so elapsed is
# accurate) and is mutually exclusive with SHARE_HISTORY (set by oh-my-zsh).
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY_TIME
unsetopt SHARE_HISTORY
# NixOS's generated ~/.zshrc sets NO_APPEND_HISTORY before this file loads,
# which makes shell exit truncate+replace the whole HISTFILE with that
# session's in-memory history instead of appending — silently clobbering
# every other entry's timestamp. Force it back on.
setopt APPEND_HISTORY
HISTSIZE=500000
SAVEHIST=500000

alias sz="source ~/dotfiles/.zshrc"

