# Make nix-ld libraries available to pip/uv venvs with compiled C extensions
export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

SSD_MOUNT="/run/media/$USER/7ABF-7932"

export PATH="$HOME/.local/bin:$HOME/dotfiles/scripts:$HOME/scripts:$HOME/Documents/Projects/rbwcheck:$PATH"

[[ -f ~/.zshrc.secrets ]] && source ~/.zshrc.secrets

[ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
