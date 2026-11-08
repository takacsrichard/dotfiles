-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("waybar")

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && systemctl --user restart workspaces-tracker.service")

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- Docker services (restart policy alone won't bring these back if they
    -- were left stopped at last shutdown, e.g. mid dev-iteration)
    hl.exec_cmd("docker compose -f /home/richard/dashboard/docker-compose.yml up -d")
    hl.exec_cmd("docker compose -f /home/richard/code/todoist-enhanced/compose.yml up -d")

end)
