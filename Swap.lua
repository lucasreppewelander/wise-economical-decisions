-- Does the loot fit, and if not, which bag item is the best one to drop?
-- Pure Lua (no game API calls) so it can be tested outside the game.

local _, ns = ...

local band = bit.band

-- A general bag (family 0) holds anything. A special bag (herb bag, quiver,
-- soul bag...) only holds items whose family shares a bit with it.
function ns.CanHold(bagFamily, itemFamily)
    return bagFamily == 0 or band(bagFamily, itemFamily or 0) ~= 0
end

-- How many units of the loot won't fit: fill partial stacks first, then
-- free slots, only in bags that can hold the item.
function ns.Leftover(loot, containers)
    local left = loot.count or 1
    local maxStack = loot.maxStack or 1
    for _, c in ipairs(containers) do
        if ns.CanHold(c.family, loot.family) then
            for _, item in ipairs(c.items) do
                if item.itemID == loot.itemID then
                    left = left - math.max(0, maxStack - (item.count or 1))
                end
            end
            left = left - (c.freeSlots or 0) * maxStack
        end
    end
    return math.max(0, left)
end

-- Bag items that may be dropped to make room for `loot`.
local function Candidates(loot, containers, opts)
    local list = {}
    for _, c in ipairs(containers) do
        if ns.CanHold(c.family, loot.family) then
            for _, item in ipairs(c.items) do
                if item.itemID ~= loot.itemID
                    and ns.ProtectionReason(item, opts.protected, opts.threshold) == nil then
                    list[#list + 1] = item
                end
            end
        end
    end
    return list
end

local function BuildSwap(state, loot, lootCount, drop, threshold)
    local unit, lootSource = ns.UnitValue(loot, threshold)
    local dropValue, dropSource = ns.StackValue(drop, threshold)
    local swap = {
        state = state,
        drop = drop, dropValue = dropValue, dropSource = dropSource,
        loot = loot, lootCount = lootCount,
        lootValue = unit * lootCount, lootSource = lootSource,
    }
    if (loot.maxStack or 1) > 1 then
        swap.fullStackValue = unit * loot.maxStack
    end
    return swap
end

-- Returns the single swap to suggest, or nil when nothing is blocked or no
-- valid drop exists. opts = { threshold = number, protected = { [itemID] = true } }
function ns.ChooseSwap(lootItems, containers, opts)
    local threshold = opts.threshold
    local blocked = {}
    for _, loot in ipairs(lootItems) do
        local left = ns.Leftover(loot, containers)
        if left > 0 then
            blocked[#blocked + 1] = { loot = loot, count = left, candidates = Candidates(loot, containers, opts) }
        end
    end
    if #blocked == 0 then return nil end

    -- Quest items, keys and profession tools: make room with the cheapest drop.
    for _, b in ipairs(blocked) do
        local kind = ns.MustHaveKind(b.loot)
        if kind and #b.candidates > 0 then
            local cheapest, cheapestValue
            for _, cand in ipairs(b.candidates) do
                local v = ns.StackValue(cand, threshold)
                if not cheapestValue or v < cheapestValue then
                    cheapest, cheapestValue = cand, v
                end
            end
            local swap = BuildSwap("musthave", b.loot, b.count, cheapest, threshold)
            swap.mustHaveKind = kind
            swap.fullStackValue = nil -- must-have loot is usually worth 0; a "0c" note is noise
            return swap
        end
    end

    -- Otherwise the pair with the highest gain (first one wins a tie).
    local best
    for _, b in ipairs(blocked) do
        for _, cand in ipairs(b.candidates) do
            local swap = BuildSwap(nil, b.loot, b.count, cand, threshold)
            swap.gain = swap.lootValue - swap.dropValue
            if not best or swap.gain > best.gain then
                best = swap
            end
        end
    end
    if not best then return nil end
    best.state = best.gain > 0 and "worth" or "notworth"
    return best
end
