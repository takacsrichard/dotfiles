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

-- driving both outputs at once (even with edp's backlight at 0) pins the amdgpu
-- display controller's memory/display clocks high system-wide -- measured
-- ~4-5w, see ~/sys/battanal/opencode_continuation/FINDINGS_20261128.md. so:
-- edp is only on when hdmi isn't plugged in.
local function has_hdmi()
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name == "HDMI-A-1" then
            return true
        end
    end
    return false
end

local function enable_edp()
    hl.monitor({
        output = "eDP-1",
        mode = "2880x1800@60",
        position = "0x0",
        scale = 2
    })
end

local function disable_edp()
    hl.monitor({ output = "eDP-1", disabled = true })
end

if has_hdmi() then
    disable_edp()
end

hl.on("monitor.added", function(monitor)
    if monitor.name == "HDMI-A-1" then
        disable_edp()
    end
end)

hl.on("monitor.removed", function(monitor)
    if monitor.name == "HDMI-A-1" then
        enable_edp()
    end
end)
