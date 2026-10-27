hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )
hl.bind("SUPER + F1", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/toggle_external_only.sh"), { description = "Monitor: Toggle external only / both" })
hl.bind("SUPER + SHIFT + ALT + C", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/compact_workspaces.sh"), { description = "Workspace: Compact (remove gaps)" })

-- screenshot submap: toggle with SUPER+ALT+N, then bare "n" fires the screenshot script
hl.define_submap("screenshot", function()
    hl.bind("n", hl.dsp.exec_cmd("~/sys/school/screenshot-full.sh"))
end)

hl.bind("SUPER + ALT + N", function()
    local currentsubmap = hl.get_current_submap()
    if currentsubmap == "screenshot" then
        hl.dispatch(hl.dsp.exec_cmd("notify-send 'Exited screenshot submap' -a 'Hyprland'"))
        hl.dispatch(hl.dsp.submap("reset"))
    elseif currentsubmap == "" then
        hl.dispatch(hl.dsp.exec_cmd("notify-send 'Entered screenshot submap' 'hit n to screenshot, SUPER+ALT+N to exit' -a 'Hyprland'"))
        hl.dispatch(hl.dsp.submap("screenshot"))
    end
end, { submap_universal = true, description = "Screenshot: Toggle bare-n submap" })
