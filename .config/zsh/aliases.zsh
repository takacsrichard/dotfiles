#============================================================
#  Aliases
# ============================================================

# multimedia 
alias sw="swayimg"
alias img="kitten icat"
alias mpl="mpv . --shf --loop-playlist"
alias mpvnr="find . -maxdepth 1 -type f -print0 | xargs -0 mpv"

#ai 
alias cla="claude"
alias cld="claude --dangerously-skip-permissions"
alias clm="claude --dangerously-skip-permissions --resume"
alias ccusage="npx ccusage@latest --json"

alias btdu="sudo btdu --auto-mount /home"

alias jp="git add . && { git commit -m 'update various things' || true; } && git push"

# dotfiles
alias hn="n $HOME/dotfiles/nix-config/home.nix"
alias cn="n $HOME/dotfiles/nix-config/configuration.nix"
alias mods="cd $HOME/dotfiles/nix-config/modules/"
alias nc="cd ~/dotfiles/nix-config/"

# simple df
alias dfs="df -hTx tmpfs -x efivarfs -x devtmpfs -x vfat"

alias fd="fd -E /staging/"
alias fdh="fd -H -E /staging/"

alias cp='cp --reflink=auto'


alias aliases="nvim $HOME/dotfiles/.config/zsh/aliases.zsh"
alias funcs="nvim $HOME/dotfiles/.config/zsh/functions.zsh"

alias n="nvim"

# btrfs balance
# screenshot
alias scr='grim -g "$(slurp)" - | wl-copy'

alias ffmstats="ffprobe -v quiet -print_format json -show_streams -show_format"

# --- Hyprland shortcuts ---
alias hrel='hyprctl reload'
alias hl='hyprlock'
alias slep='systemctl suspend'

alias memusers='ps axo rss,comm --sort=-rss | head -n 6 | awk '\''NR==1 {print $1, $2; next} {printf "%.2f MB\t%s\n", $1/1024, $2}'\'''
alias memuserspriv='ps axo pid,comm --sort=-rss | head -n 6 | awk '\''NR==1 {next} {print $1, $2}'\'' | while read pid name; do priv=$(awk '\''/^Private_Dirty/{sum+=$2} END{printf "%.2f MB", sum/1024}'\'' /proc/$pid/smaps 2>/dev/null); echo "$priv\t$name"; done | sort -rn'
alias t="trans"
alias filesbyline='find . -type f -name ".*" -o -type f | xargs wc -l | sort -n'

# --- Aliases with colors ---
# wl-copy forks a daemon to hold the clipboard and keeps the fds it inherited.
# Inside out=$(cmd 2>&1) that write end never closes, so the caller blocks
# forever. Hand the daemon its own fds, and no-op with no compositor around.
_clipcopy() {
    [[ -n $WAYLAND_DISPLAY ]] && (( $+commands[wl-copy] )) || return 0
    print -rn -- "$1" | wl-copy >/dev/null 2>&1
}

_ezals() {
    eza -la --git --header --icons -o --no-permissions "$@"
    local target=. arg
    for arg in "$@"; do [[ -e $arg ]] && target=$arg; done
    local abs=${target:A}
    _clipcopy "$abs"
    if [[ -t 1 ]]; then print -r -- "Copied: $abs"; fi
}
alias ls='_ezals'
alias l='_ezals'

# compdef only exists after compinit (interactive shells), and _eza only
# resolves if eza's completion dir reached fpath. ~/.zshrc builds fpath from
# $NIX_PROFILES, but tmux hands new panes the environment cached when its
# server started, and that copy is missing /etc/profiles/per-user/$USER --
# which is where home-manager's _eza lives. Add it here and autoload by hand
# (compinit has already run), falling back to file completion if it's absent.
if (( $+functions[compdef] )); then
    [[ -d /etc/profiles/per-user/$USER/share/zsh/site-functions ]] &&
        fpath=(/etc/profiles/per-user/$USER/share/zsh/site-functions $fpath)
    if (( $+functions[_eza] )) || autoload -Uz +X _eza 2>/dev/null; then
        compdef _eza _ezals
    else
        compdef _files _ezals
    fi
fi
alias grep='grep --color=auto'
alias c='clear'

# --- System shortcuts ---
alias localip='ip -br addr show | grep -v lo'

# system stats
alias battinfo="upower -i /org/freedesktop/UPower/devices/battery_BAT0"

# --- Bluetooth&Wifi shortcuts ---
alias blon='bluetoothctl power on'
alias bloff='bluetoothctl power off'
alias wifion="nmcli radio wifi on"
alias wifioff="nmcli radio wifi off"
alias bt="bluetui"
alias wt="nmtui"
alias wifitui="nmtui"
