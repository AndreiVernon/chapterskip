-- chapterskip.lua
--
-- Ain't Nobody Got Time for That
--
-- This script skips or pauses chapters based on their title.
local categories = {
    prologue = "^Prologue/^Intro",
    opening = "^OP/ OP$/^Opening",
    ending = "^ED/ ED$/^Ending",
    preview = "Preview$"
}
local options = {
    enabled = true,
    skip_once = true,
    categories = "",
    skip = "",
    pause = ""
}
mp.options = require "mp.options"

function matches(i, title, action_type)
    local target_option = action_type == "pause" and options.pause or options.skip
    for category in string.gmatch(target_option, " *([^;]*[^; ]) *") do
        if categories[category:lower()] then
            if string.find(category:lower(), "^idx%-") == nil then
                if title then
                    for pattern in string.gmatch(categories[category:lower()], "([^/]+)") do
                        if string.match(title, pattern) then
                            return true
                        end
                    end
                end
            else
                for pattern in string.gmatch(categories[category:lower()], "([^/]+)") do
                    if tonumber(pattern) == i then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local skipped = {}
local paused = {}
local parsed = {}

function chapterskip(_, current)
    mp.options.read_options(options, "chapterskip")
    if not options.enabled then return end
    for category in string.gmatch(options.categories, "([^;]+)") do
        name, patterns = string.match(category, " *([^+>]*[^+> ]) *[+>](.*)")
        if name then
            categories[name:lower()] = patterns
        elseif not parsed[category] then
            mp.msg.warn("Improper category definition: " .. category)
        end
        parsed[category] = true
    end
    local chapters = mp.get_property_native("chapter-list")
    local skip = false
    for i, chapter in ipairs(chapters) do
        if (not options.skip_once or not paused[i]) and matches(i, chapter.title, "pause") then
            if i == current + 1 then
                mp.set_property("pause", "yes")
                paused[i] = true
                mp.osd_message("Paused at chapter: " .. (chapter.title or "Chapter " .. i), 3)
                return
            end
        end
        if (not options.skip_once or not skipped[i]) and matches(i, chapter.title, "skip") then
            if i == current + 1 or skip == i - 1 then
                if skip then
                    skipped[skip] = true
                end
                skip = i
            end
        elseif skip then
            mp.set_property("time-pos", chapter.time)
            skipped[skip] = true
            return
        end
    end
    if skip then
        if mp.get_property_native("playlist-count") == mp.get_property_native("playlist-pos-1") then
            return mp.set_property("time-pos", mp.get_property_native("duration"))
        end
        mp.commandv("playlist-next")
    end
end

mp.observe_property("chapter", "number", chapterskip)
mp.register_event("file-loaded", function() 
    skipped = {} 
    paused = {}
end)
