hl.config({
    misc = {
        background_color = "rgba(000000FF)",
    },
	--    input = {
	--        accel_profile = "flat",
	-- force_no_accel = true;
	       -- sensitivity = -0.05
	--    }
})

-- Built-in display at 2x scale (HiDPI)
-- 60Hz default to cut Hyprland's vblank wakeup rate; toggle to 90Hz via the
-- waybar custom/refresh-toggle button (runs hyprctl eval hl.monitor(...) at runtime)
hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@60",
    position = "0x0",
    scale = 2
})

-- External monitor stays at 1x, repositioned to account for eDP-1's logical width (2880/2 = 1440)
hl.monitor({
    output = "HDMI-A-1",
    mode = "1920x1080@60",
    position = "1440x0",
    scale = 1
})
