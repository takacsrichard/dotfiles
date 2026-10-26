My dotfiles should be in ~/dotfiles/.

Laptop is an Asus Vivobook m3402qa

nixos 26.05, btrfs, hyprland

always search the web before answering.

nix config is in /home/richard/dotfiles/nix-config

# Writing style

Code comments: always lowercase, no capitalization, informal tone.

Language choice: for projects/sysadmin tasks, prefer python or shell unless specified otherwise or another language is clearly better suited. For homework, use R unless specified otherwise.

Math/code spacing: avoid extra spaces around operators and in arguments. Write `5+5` not `5 + 5`, `arg1=1, arg2=2` not `arg1 = 1, arg2 = 2`, unless specified otherwise.

Code density: keep code concise, avoid blank lines unless they help readability a lot, especially inside functions.

Prose (cover letters, assignments, homework): avoid overly formal language. Minimize adjectives/adverbs. Be direct and to the point. No bootlicking/flattery.

LaTeX/Typst math: prefer inline math over display math unless display math is clearly better suited (equation too large, too complex, or important enough to stand out).

# systemd

Debug WITHOUT rebuilding: replicate the unit env with
`env -i HOME=/home/richard PATH="$(systemctl show UNIT -p Environment --value|tr ' ' '\n'|grep ^PATH=|cut -d= -f2-)" bash script`.
Scripts referenced by absolute path (not store path) need no rebuild to edit.

Traps: journald `MaxLevelStore=4` silently drops info-level stdout, so failures
log no reason — set `SyslogLevel="warning"` per unit. Units get a minimal PATH,
not the login one; add `bash` (for `env` shebangs), `procps`, `"/run/wrappers"`
(sudo) to `path`. No `User=` means root, so `sudo` dies with no TTY. Pin sudoers
commands to `config.systemd.package`, not `pkgs.systemd` — different store paths,
rule silently won't match. Verify flags exist (`pgrep` has `--quiet`, no `-q`).
