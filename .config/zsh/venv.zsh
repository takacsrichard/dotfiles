# venv_mng (global_scripts, symlinked into ~/.local/bin) owns
# create/delete/activate/deactivate/list via a stdin menu. It can't change
# this shell's own environment though, so activate/deactivate print the
# shell command to run and we eval it here.
venvm() { eval "$(venv_mng "$@")"; }
