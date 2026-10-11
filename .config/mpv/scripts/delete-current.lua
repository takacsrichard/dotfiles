local function delete_current()
    local path = mp.get_property("path")
    if not path then return end

    local ok, err = os.remove(path)

    if ok then
        mp.osd_message("Deleted: " .. path)
        local count = mp.get_property_number("playlist-count", 1)
        if count <= 1 then
            mp.commandv("quit")
        else
            mp.commandv("playlist-next", "force")
        end
    else
        mp.osd_message("Delete failed: " .. tostring(err))
    end
end

mp.add_key_binding("ctrl+DEL", "delete-current", delete_current)
