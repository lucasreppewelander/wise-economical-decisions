-- What an item is worth, and whether it may ever be suggested as a drop.
-- Pure Lua (no game API calls) so it can be tested outside the game.

local _, ns = ...

local AH_CUT = 0.95

-- Copper per unit, and where the number came from ("vendor" or "AH").
-- The AH price only counts when it's at least `threshold` times the vendor
-- price, and never for bound items (they can't be sold on the AH).
function ns.UnitValue(item, threshold)
    local vendor = item.vendor or 0
    local ah = item.ah
    if not item.bound and ah and ah > 0 and ah >= threshold * vendor then
        return math.floor(ah * AH_CUT), "AH"
    end
    return vendor, "vendor"
end

function ns.StackValue(item, threshold)
    local unit, source = ns.UnitValue(item, threshold)
    return unit * (item.count or 1), source
end

local function IsTool(item)
    local D = ns.Data
    return D.TOOLS[item.itemID] == true
        or (item.classID == D.CLASS.WEAPON and item.subclassID == D.FISHING_POLE_SUBCLASS)
end

local function IsQuest(item)
    return item.isQuest == true or item.classID == ns.Data.CLASS.QUEST
end

-- Why an item must never be suggested as a drop, or nil if it may be.
function ns.ProtectionReason(item, userProtected, threshold)
    local D = ns.Data
    if userProtected and userProtected[item.itemID] then return "user" end
    if item.opening then return "opening" end -- the container you're looting from
    if IsTool(item) then return "tool" end
    if IsQuest(item) then return "quest" end
    if D.TELEPORTS[item.itemID] then return "teleport" end
    if item.classID == D.CLASS.KEY then return "key" end
    if item.classID == D.CLASS.PROJECTILE then return "ammo" end
    if item.itemID == D.SOUL_SHARD then return "soulshard" end
    if ns.UnitValue(item, threshold) == 0 then return "novalue" end
    return nil
end

-- Loot that's always worth making room for, whatever its price.
function ns.MustHaveKind(item)
    if IsQuest(item) then return "quest" end
    if item.classID == ns.Data.CLASS.KEY then return "key" end
    if IsTool(item) then return "tool" end
    return nil
end

-- Money as text with coin icons, e.g. "41 [g] 20 [s] 05 [c]".
-- Our own formatter: GetCoinTextureString doesn't exist on WoW Forever.
ns.GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"
ns.SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
ns.COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"

function ns.FormatMoney(copper)
    copper = math.max(0, math.floor(copper or 0))
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("%d %s %02d %s %02d %s", g, ns.GOLD_ICON, s, ns.SILVER_ICON, c, ns.COPPER_ICON)
    elseif s > 0 then
        return string.format("%d %s %02d %s", s, ns.SILVER_ICON, c, ns.COPPER_ICON)
    end
    return string.format("%d %s", c, ns.COPPER_ICON)
end
