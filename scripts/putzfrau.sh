#!/usr/bin/env bash
#
# putzfrau: remove generations older than 7 days, GC the nix store, optimise
# it, clear language/package manager caches, and tidy up misc app caches.

set -euo pipefail

sudo nix-collect-garbage --delete-older-than 7d
nix store gc
nix store optimise
command -v go &>/dev/null && go clean -modcache -cache || { chmod -R u+w ~/go/pkg/mod ~/.cache/go-build 2>/dev/null || true; rm -rf ~/go/pkg/mod ~/.cache/go-build; }
command -v npm &>/dev/null && npm cache clean --force || rm -rf ~/.npm/_cacache
command -v uv &>/dev/null && uv cache clean || rm -rf ~/.cache/uv
rm -rf ~/.cache/mozilla ~/.cache/mesa_shader_cache
sudo journalctl --vacuum-time=2weeks
restic cache --cleanup
rm -rf ~/.cache/pip ~/.cache/fontconfig ~/.cache/thumbnails ~/.cache/R
