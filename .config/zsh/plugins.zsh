# --- zoxide ---
eval "$(zoxide init zsh)"

# --- fzf-tab: fuzzy picker for the normal zsh completion menu (any command's args) ---
# must load after compinit (already ran via oh-my-zsh) and before zsh-syntax-highlighting
[ -n "$FZF_TAB_SHARE" ] && source "$FZF_TAB_SHARE/fzf-tab.plugin.zsh"

# --- zoxide-insert: expand the word under the cursor to zoxide's best frecency match ---
# e.g. type `cd homew<C-x>` anywhere on the line, not just after `z`/`cd`
_zoxide_insert() {
    local word="${LBUFFER##*[[:space:]]}"
    [[ -z "$word" ]] && return
    local result
    result=$(zoxide query -- "$word" 2>/dev/null)
    [[ -z "$result" ]] && return
    LBUFFER="${LBUFFER%$word}$result"
    zle reset-prompt
}
zle -N _zoxide_insert
bindkey '^X' _zoxide_insert
