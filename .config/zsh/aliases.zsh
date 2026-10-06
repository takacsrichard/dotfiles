#============================================================
#  Aliases
# ============================================================

# temp
alias getkurt="wget -r -np -N -nd -A '*.*' https://statmath.wu.ac.at/\~hornik/Comp/comp_facts.html"

# multimedia 
alias sw="swayimg"
alias img="kitten icat"
alias m="mpv"
alias mpl="mpv . --shf --loop-playlist"
alias mpvnr="find . -maxdepth 1 -type f -print0 | xargs -0 mpv"
alias getmusic="yt-dlp -x --audio-format opus --cookies-from-browser firefox"

#ai 
alias cla="claude"
alias cld="claude --dangerously-skip-permissions"
alias clm="claude --resume"
alias dumb="claude --model claude-haiku-4-5-20251001"   # haiku 4.5
alias normal="claude --model claude-sonnet-4-6"         # sonnet 4.6
alias better="claude --model claude-opus-4-8"           # opus 4.8
alias agy="agy"
alias mediumclaude="CLAUDE_CODE_EFFORT_LEVEL=medium cla"
alias ccusage="npx ccusage@latest --json"

# networking, bluetooth, etc
alias bt="bluetui"
alias wt="wifitui"
alias wifitui="nmtui"
alias wifirec="nmcli radio wifi off && nmcli radio wifi on"

alias btdu="sudo btdu --auto-mount /home"

alias todo="n $HOME/Documents/sysadmin/todo.txt"
alias jp="git add . && git commit -m 'stuff' && git push"
alias gs="git status"
alias gsp="git status --porcelain"
alias pushall="git add . && { git commit -m 'update various things' || true; } && git push"
alias hn="n $HOME/dotfiles/nix-config/home.nix"
alias cn="n $HOME/dotfiles/nix-config/configuration.nix"
alias mods="cd $HOME/dotfiles/nix-config/modules/"
alias dfs="df -hTx tmpfs -x efivarfs -x devtmpfs -x vfat"
alias fd="fd -E /staging/"
alias fdh="fd -H -E /staging/"
alias lo="libreoffice"
alias cp='cp --reflink=auto'
alias aliases="nvim $HOME/dotfiles/.config/zsh/aliases.zsh"
alias funcs="nvim $HOME/dotfiles/.config/zsh/functions.zsh"
alias n="nvim"
# btrfs balance
alias reclaim="sudo btrfs balance start -dusage=50 /home"
alias restartwaybar="pkill waybar; waybar &>/dev/null & disown"
alias nc="cd ~/dotfiles/nix-config/"
# screenshot
alias scr='grim -g "$(slurp)" - | wl-copy'


alias ffmstats="ffprobe -v quiet -print_format json -show_streams -show_format"
alias h="history"
alias qsrestart='pkill -9 -x quickshell 2>/dev/null; pkill quickshell 2>/dev/null; sleep 0.5; qs -c ii &'

# --- Hyprland shortcuts ---
alias hmon='hyprctl monitors'
alias hcl='hyprctl clients'
alias hwork='hyprctl workspaces'
alias hdev='hyprctl devices'        # input devices (mice, keyboards)
alias hlay='hyprctl layers'         # active layer surfaces (bars, overlays)
alias hrel='hyprctl reload'
alias hkill='hyprctl kill'          # click to kill a window
alias hver='hyprctl version'
alias hl='hyprlock'
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
alias fafe='fastfetch'
alias please='sudo'
alias e='nvim'
alias f='sudo -E nnn -H'
alias c='clear'
alias htopcopy="copy 'ps auxf'"

# --- Directory shortcuts ---
alias ssd='cd "$SSD_MOUNT"'
alias hdd="cd /run/media/$USER/Expansion"
alias home="cd $HOME"
alias config='cd ~/.config'
alias kdeconf='cd ~/.config'
alias ddls="cd $HOME/Downloads"
alias docs="cd $HOME/Documents"
alias dotf="cd $HOME/dotfiles"

# --- System shortcuts ---
alias syslog='journalctl -f'
alias slep='systemctl suspend'
alias localip='ip -br addr show | grep -v lo'

# system stats
alias battinfo="upower -i /org/freedesktop/UPower/devices/battery_BAT0"

# --- Bluetooth shortcuts ---
alias blon='bluetoothctl power on'
alias bloff='bluetoothctl power off'

# --- Misc ---
alias weather='curl wttr.in'
alias largestls='ls -lhS'

# --- KDE Plasma usage stats ---
# Not used anymore
alias plasma-counts="sqlite3 ~/.local/share/kactivitymanagerd/resources/database \
    \"SELECT initiatingAgent, COUNT(*) as launch_count \
    FROM ResourceEvent \
    WHERE initiatingAgent NOT LIKE 'org.kde.plasma%' \
    AND initiatingAgent NOT LIKE 'org.kde.libtaskmanager' \
    AND initiatingAgent NOT LIKE 'org.kde.krunner' \
    AND initiatingAgent NOT LIKE '%desktop-portal%' \
    GROUP BY initiatingAgent ORDER BY launch_count DESC;\""

alias plasma-scores="sqlite3 ~/.local/share/kactivitymanagerd/resources/database \
    \"SELECT initiatingAgent, targettedResource, cachedScore \
    FROM ResourceScoreCache \
    WHERE scoreType = 0 \
    AND initiatingAgent NOT LIKE 'org.kde.plasma%' \
    AND initiatingAgent NOT LIKE 'org.kde.libtaskmanager' \
    AND initiatingAgent NOT LIKE 'org.kde.krunner' \
    AND initiatingAgent NOT LIKE '%desktop-portal%' \
    ORDER BY cachedScore DESC LIMIT 15;\""

# --- R / LaTeX ---
rr()   { Rscript "$1" }
rrmd() { Rscript -e "rmarkdown::render('$1', output_format='pdf_document')" }
lmk()  { latexmk -pdf "$1" }


cpw() {copy "readlink -f '$1'"}

# z only exists once zoxide has been initialized, i.e. interactive shells.
# Without the builtin fallback, cd in a script is a silent no-op -- "command
# not found: z", and the script carries on in the wrong directory.
cd() {
    if (( $+functions[z] )); then
        z "$@"
    else
        builtin cd "$@"
    fi
}

# Only list when there is a terminal to list to, otherwise the listing lands
# inside every v=$(cd dir && ...) capture in anything that sources this file.
chpwd() {
    [[ -o interactive && -t 1 ]] || return 0
    eza -la --git --header --icons -o --no-permissions
}

mdc() {
    mkdir -p -- "$1" || return
    local abs=${1:A}
    _clipcopy "$abs"
    if [[ -t 1 ]]; then print -r -- "Copied: $abs"; fi
}

