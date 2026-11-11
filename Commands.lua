-- Slash command parsing (pure Lua, tested outside the game).

local _, ns = ...

function ns.ItemIDFromLink(text)
    local id = text and text:match("item:(%d+)")
    return id and tonumber(id) or nil
end

local KNOWN = { help = true, protect = true, unprotect = true, list = true, threshold = true, demo = true }

-- "/wed <cmd> <arg>" -> { cmd = ..., itemID = ..., number = ... }
function ns.ParseSlash(msg)
    local word, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local cmd = (word or ""):lower()
    if not KNOWN[cmd] then return { cmd = "help" } end
    local result = { cmd = cmd }
    if cmd == "protect" or cmd == "unprotect" then
        result.itemID = ns.ItemIDFromLink(rest)
    elseif cmd == "threshold" then
        result.number = tonumber(rest)
    end
    return result
end
