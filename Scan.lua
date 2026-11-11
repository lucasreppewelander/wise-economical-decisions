-- Turns the loot window and bags into plain item records.
-- Every game call goes through an `api` table so tests can pass a fake one;
-- GameAPI() builds the real one and is the only place WoW globals are touched.

local ADDON_NAME, ns = ...

local NUM_BAGS = 4 -- backpack (0) plus bags 1-4
local KEYRING_FAMILY = 256

-- Fields we read from GetItemInfo's return list
local function ItemInfo(api, linkOrID)
    local name, link, quality, _, _, _, _, maxStack, _, texture, sellPrice, classID, subclassID, bindType =
        api.GetItemInfo(linkOrID)
    if not name then return nil end
    return {
        name = name, link = link, quality = quality, maxStack = maxStack or 1, icon = texture,
        vendor = sellPrice or 0, classID = classID, subclassID = subclassID, bindType = bindType,
    }
end

local CONTAINER_CLASS = 1

local function Record(api, itemID, link, info, count)
    -- For a bag item, GetItemFamily returns the bag type it *is*, not where it fits.
    local family = info.classID == CONTAINER_CLASS and 0 or (api.GetItemFamily(link or itemID) or 0)
    return {
        itemID = itemID, link = link or info.link, name = info.name, icon = info.icon,
        quality = info.quality, count = count or 1, maxStack = info.maxStack, vendor = info.vendor,
        ah = api.GetAuctionPrice(itemID), family = family,
        classID = info.classID, subclassID = info.subclassID, bound = false, isQuest = false,
    }
end

-- Items in the loot window, or nil, "pending" if any item isn't cached yet.
-- Coins, currency, locked slots (group loot that isn't yours) are skipped.
function ns.ScanLoot(api)
    local items, pending = {}, false
    for i = 1, api.GetNumLootItems() do
        if api.IsItemSlot(i) then
            local _, _, quantity, _, quality, locked, isQuestItem, questID = api.GetLootSlotInfo(i)
            local link = api.GetLootSlotLink(i)
            local itemID = ns.ItemIDFromLink(link)
            if itemID and not locked then
                local info = ItemInfo(api, link)
                if not info then
                    pending = true
                    api.RequestLoad(itemID)
                else
                    local r = Record(api, itemID, link, info, quantity)
                    r.quality = quality or r.quality
                    r.bound = info.bindType == 1
                    r.isQuest = (isQuestItem and true or false) or questID ~= nil
                    r.lootSlot = i
                    items[#items + 1] = r
                end
            end
        end
    end
    if pending then return nil, "pending" end
    return items
end

-- Containers (backpack first, then bags 1-4, then the keyring), or nil, "pending".
function ns.ScanBags(api)
    local containers, pending = {}, false
    local bagIDs = {}
    for bag = 0, NUM_BAGS do bagIDs[#bagIDs + 1] = bag end
    -- Looted keys go straight to the keyring, so it counts for fitting.
    if api.KEYRING then bagIDs[#bagIDs + 1] = api.KEYRING end
    for _, bag in ipairs(bagIDs) do
        local numSlots = api.GetContainerNumSlots(bag) or 0
        if numSlots > 0 then
            local free, family = api.GetContainerNumFreeSlots(bag)
            if bag == api.KEYRING then family = KEYRING_FAMILY end
            local c = { bag = bag, family = family or 0, freeSlots = free or 0, items = {} }
            for slot = 1, numSlots do
                local ci = api.GetContainerItemInfo(bag, slot)
                if ci and ci.itemID then
                    local info = ItemInfo(api, ci.hyperlink or ci.itemID)
                    if not info then
                        pending = true
                        api.RequestLoad(ci.itemID)
                    else
                        local r = Record(api, ci.itemID, ci.hyperlink, info, ci.stackCount)
                        r.icon = ci.iconFileID or r.icon
                        r.quality = ci.quality or r.quality
                        r.bound = ci.isBound and true or false
                        -- A clam/junkbox you're looting stays locked in the bag until emptied
                        r.opening = (ci.isLocked and ci.hasLoot) and true or false
                        local q = api.GetContainerItemQuestInfo(bag, slot)
                        r.isQuest = q ~= nil and ((q.isQuestItem and true or false) or q.questID ~= nil)
                        r.bag, r.slot = bag, slot
                        c.items[#c.items + 1] = r
                    end
                end
            end
            containers[#containers + 1] = c
        end
    end
    if pending then return nil, "pending" end
    return containers
end

-- The real game API. Only called in game.
function ns.GameAPI()
    local C_Item, C_Container = C_Item, C_Container
    local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local GetItemFamily = (C_Item and C_Item.GetItemFamily) or GetItemFamily
    local ITEM_SLOT = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or LOOT_SLOT_ITEM or 1

    return {
        KEYRING = (Enum and Enum.BagIndex and Enum.BagIndex.Keyring) or KEYRING_CONTAINER,
        GetNumLootItems = GetNumLootItems,
        IsItemSlot = function(i) return GetLootSlotType(i) == ITEM_SLOT end,
        GetLootSlotInfo = GetLootSlotInfo,
        GetLootSlotLink = GetLootSlotLink,
        GetItemInfo = GetItemInfo,
        RequestLoad = function(itemID)
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
        end,
        GetItemFamily = GetItemFamily,
        GetAuctionPrice = function(itemID)
            if not (Auctionator and Auctionator.API and Auctionator.API.v1) then return nil end
            local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
            if ok and type(price) == "number" then return price end
            return nil
        end,
        GetContainerNumSlots = C_Container.GetContainerNumSlots,
        GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots,
        GetContainerItemInfo = C_Container.GetContainerItemInfo,
        GetContainerItemQuestInfo = C_Container.GetContainerItemQuestInfo,
    }
end
