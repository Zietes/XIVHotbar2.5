--[[
Locate the XIVHotbar2 keybind file for the current player + job.

XIVHotbar2 stores per-character / per-job hotbar bindings at:
    Windower/addons/XIVHotbar2/data/<Character>/<job>.lua
Plus a cross-job General.lua in the same directory.

Returns absolute path string or nil if nothing matches.
]]

local locator = {}

local SEP = package.config:sub(1, 1) or '\\'
local function normalize(p)
    p = tostring(p or '')
    p = p:gsub('/', SEP)
    if p:sub(-1) ~= SEP then p = p .. SEP end
    return p
end

-- The editor is now bundled inside XIVHotbar2 itself, so the keybind files and
-- icons live under THIS addon's own folder. No need to climb to the addons
-- root and guess a sibling 'XIVHotbar2' directory anymore.
local addon_dir = normalize(windower.addon_path or '')
local XH_DATA_DIR = addon_dir .. 'data' .. SEP

local function file_exists(path)
    local f = io.open(path, 'r')
    if f then f:close() return true end
    return false
end

-- Candidate filename forms in priority order.
local function candidates(player, job)
    local out = {}
    if player and player ~= '' and job and job ~= '' then
        local char = XH_DATA_DIR .. player .. SEP
        table.insert(out, char .. job:lower() .. '.lua')
        table.insert(out, char .. job:upper() .. '.lua')
        local char_l = XH_DATA_DIR .. player:lower() .. SEP
        table.insert(out, char_l .. job:lower() .. '.lua')
    end
    return out
end

function locator.find_active(player, job)
    for _, p in ipairs(candidates(player, job)) do
        if file_exists(p) then
            return { path = p, filename = p:match('([^\\/]+)$') }
        end
    end
    return nil
end

function locator.data_dir()    return XH_DATA_DIR     end
function locator.char_dir(p)   return XH_DATA_DIR .. (p or '?') .. SEP end
function locator.sep()         return SEP             end

-- XIVHotbar2's icon root, inside this addon: images/icons/
function locator.icons_dir()
    return addon_dir .. 'images' .. SEP .. 'icons' .. SEP
end

-- Diagnostic: list every file we would try, with ✓/✗ for whether it exists.
function locator.list_candidates(player, job)
    local out = {}
    for _, p in ipairs(candidates(player, job)) do
        table.insert(out, { path = p, exists = file_exists(p) })
    end
    return out
end

return locator
