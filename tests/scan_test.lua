-- Run from repo root: luajit tests/scan_test.lua
local T = dofile("tests/helper.lua")
local ns = T.load({ "Commands.lua", "Scan.lua" })

local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::60:::::|h[Item " .. id .. "]|h|r" end

-- A fake game API built from plain tables (shape documented in Scan.lua).
local function fakeAPI(spec)
    local api = { requested = {}, KEYRING = -2 }
    local function id(x) return type(x) == "number" and x or ns.ItemIDFromLink(x) end
    function api.GetNumLootItems() return #(spec.loot or {}) end
    function api.IsItemSlot(i) return spec.loot[i].isItem ~= false end
    function api.GetLootSlotInfo(i)
        local s = spec.loot[i]
        return 134400, "Item " .. tostring(s.id), s.quantity or 1, nil, 1, s.locked or false, s.isQuestItem or false, s.questID
    end
    function api.GetLootSlotLink(i) local s = spec.loot[i]; return s.id and link(s.id) or nil end
    function api.GetItemInfo(x)
        local d = spec.items[id(x)]
        if not d then return nil end
        return "Item " .. id(x), link(id(x)), 1, 10, 1, "Type", "SubType", d.maxStack or 1, "",
            d.texture or 134400, d.sellPrice or 0, d.classID or 15, d.subclassID or 0, d.bindType or 0
    end
    function api.RequestLoad(itemID) api.requested[#api.requested + 1] = itemID end
    function api.GetItemFamily(x) local d = spec.items[id(x)]; return d and d.family or 0 end
    function api.GetAuctionPrice(itemID) return spec.ah and spec.ah[itemID] or nil end
    function api.GetContainerNumSlots(b) local bag = spec.bags[b]; return bag and bag.numSlots or 0 end
    function api.GetContainerNumFreeSlots(b) local bag = spec.bags[b]; return bag.free, bag.family end
    function api.GetContainerItemInfo(b, s)
        local it = spec.bags[b].slots[s]
        if not it then return nil end
        return { itemID = it.id, stackCount = it.count or 1, hyperlink = link(it.id), iconFileID = 134400, quality = 1, isBound = it.bound or false, isLocked = it.locked or false, hasLoot = it.hasLoot or false }
    end
    function api.GetContainerItemQuestInfo(b, s)
        local it = spec.bags[b].slots[s]
        return { isQuestItem = it.isQuestItem or false, questID = it.questID }
    end
    return api
end

local items = {
    [2589] = { maxStack = 20, sellPrice = 13, classID = 7 },        -- Linen Cloth
    [200]  = { sellPrice = 1000, classID = 4, bindType = 1 },       -- BoP ring
    [600]  = { sellPrice = 0, classID = 15 },                        -- quest starter
    [2447] = { maxStack = 20, sellPrice = 10, classID = 7, family = 32 }, -- Peacebloom
    [4371] = { sellPrice = 200, classID = 7 },                       -- Bronze Tube
}

-- Loot: coin and locked slots are skipped; item slots become records
local loot = ns.ScanLoot(fakeAPI({ items = items, loot = {
    { isItem = false },
    { id = 200, locked = true },
    { id = 2589, quantity = 5 },
} }))
T.eq("loot: one item", #loot, 1)
T.eq("loot: linen fields", { loot[1].itemID, loot[1].count, loot[1].maxStack, loot[1].vendor, loot[1].lootSlot, loot[1].ah },
    { 2589, 5, 20, 13, 3, nil })

loot = ns.ScanLoot(fakeAPI({ items = items, ah = { [200] = 50000 }, loot = { { id = 200 }, { id = 600, questID = 123 } } }))
T.eq("loot: bind on pickup is bound", loot[1].bound, true)
T.eq("loot: ah price read", loot[1].ah, 50000)
T.eq("loot: starts quest", loot[2].isQuest, true)

-- Uncached loot -> pending, and a data request is made
local api = fakeAPI({ items = items, loot = { { id = 9999 } } })
T.eq("loot: uncached pending", { ns.ScanLoot(api) }, { nil, "pending" })
T.eq("loot: requested load", api.requested, { 9999 })

-- Bags: backpack + herb bag; missing bag 2 skipped
local bags = ns.ScanBags(fakeAPI({ items = items, bags = {
    [0] = { numSlots = 2, free = 1, family = 0, slots = { [2] = { id = 2589, count = 7 } } },
    [1] = { numSlots = 1, free = 0, family = 32, slots = { [1] = { id = 2447, count = 3 } } },
} }))
T.eq("bags: two containers", #bags, 2)
T.eq("bags: herb bag", { bags[2].bag, bags[2].family, bags[2].freeSlots }, { 1, 32, 0 })
T.eq("bags: herb item", { bags[2].items[1].count, bags[2].items[1].bag, bags[2].items[1].slot, bags[2].items[1].family }, { 3, 1, 1, 32 })
T.eq("bags: backpack item", { bags[1].items[1].itemID, bags[1].items[1].slot, bags[1].items[1].vendor }, { 2589, 2, 13 })

bags = ns.ScanBags(fakeAPI({ items = items, bags = {
    [0] = { numSlots = 1, free = 0, family = 0, slots = { [1] = { id = 600, questID = 55, bound = true } } },
} }))
T.eq("bags: quest + bound flags", { bags[1].items[1].isQuest, bags[1].items[1].bound }, { true, true })

-- Uncached bag item -> pending
T.eq("bags: uncached pending", { ns.ScanBags(fakeAPI({ items = items, bags = {
    [0] = { numSlots = 1, free = 0, family = 0, slots = { [1] = { id = 8888 } } },
} })) }, { nil, "pending" })
-- An unequipped bag reports its bag type as its family; as an item it only fits general bags
local herbBagItems = { [5765] = { classID = 1, family = 32, sellPrice = 500 } }
loot = ns.ScanLoot(fakeAPI({ items = herbBagItems, loot = { { id = 5765 } } }))
T.eq("loot: bag item has family 0", loot[1].family, 0)
-- Keyring is scanned with the keyring family, even if the game reports 0
bags = ns.ScanBags(fakeAPI({ items = items, bags = {
    [0]  = { numSlots = 1, free = 0, family = 0, slots = { [1] = { id = 2589 } } },
    [-2] = { numSlots = 4, free = 4, family = 0, slots = {} },
} }))
T.eq("bags: keyring container", { #bags, bags[2].bag, bags[2].family, bags[2].freeSlots }, { 2, -2, 256, 4 })

-- A container being opened (locked, has loot) is flagged; one just picked up (locked only) is not
bags = ns.ScanBags(fakeAPI({ items = items, bags = {
    [0] = { numSlots = 2, free = 0, family = 0, slots = {
        [1] = { id = 2589, locked = true, hasLoot = true },
        [2] = { id = 4371, locked = true } } },
} }))
T.eq("bags: opening flag", { bags[1].items[1].opening, bags[1].items[2].opening }, { true, false })
print("scan_test: all passed")
