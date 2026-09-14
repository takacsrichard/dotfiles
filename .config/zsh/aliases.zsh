#============================================================
#  Aliases
# ============================================================

alias mediumclaude="CLAUDE_CODE_EFFORT_LEVEL=medium cla"
alias getmusic="yt-dlp -x --audio-format opus --cookies-from-browser firefox"
alias ccusage="npx ccusage@latest --json"
alias img="kitten icat"
alias gs="git status"
alias hn="n /home/richard/dotfiles/nix-config/home.nix"
alias cn="n /home/richard/dotfiles/nix-config/configuration.nix"
alias dfs="df -hTx tmpfs -x efivarfs -x devtmpfs -x vfat"
alias fd="fd -H -E /staging/"
alias m="mpv"
alias mpvnr="find . -maxdepth 1 -type f -print0 | xargs -0 mpv"
alias lo="libreoffice"
alias mv="mv -i"
alias szsh="sourcezsh"
alias sz="sourcezsh"
alias aliases="nvim /home/richard/dotfiles/.config/zsh/aliases.zsh"
alias cla="claude --dangerously-skip-permissions"
alias clm="claude --dangerously-skip-permissions --resume"
alias dumb="claude --dangerously-skip-permissions --model claude-haiku-4-5-20251001"   # haiku 4.5
alias normal="claude --dangerously-skip-permissions --model claude-sonnet-4-6"         # sonnet 4.6
alias better="claude --dangerously-skip-permissions --model claude-opus-4-8"           # opus 4.8
alias bt="bluetui"
alias wt="wifitui"
alias wifitui="nmtui"
alias wifirec="nmcli radio wifi off && nmcli radio wifi on"
alias n="nvim"
# btrfs balance
alias reclaim="sudo btrfs balance start -dusage=50 /home"
alias restartwaybar="pkill waybar; waybar &>/dev/null & disown"

# screenshot
alias scr='grim -g "$(slurp)" - | wl-copy'


alias ffmstats="ffprobe -v quiet -print_format json -show_streams -show_format"
alias h="history"
alias bootstats='python3 ~/dotfiles/scripts/bootstats'
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
alias ls='ls --color=auto'
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

