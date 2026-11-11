-- Wise Economic Decisions: when loot won't fit, suggest which bag item to drop.
-- Wires the pure logic (Value/Swap/Commands) and Scan to game events, the
-- swap card and the /wed slash command.

local ADDON_NAME, ns = ...

local DB
local api
local lootOpen = false
local queued = false
local demoStep = 0

local function Print(msg)
    print("|cffffd100Wise Economic Decisions:|r " .. msg)
end

local function ItemLink(itemID)
    local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local _, link = GetItemInfo(itemID)
    return link or ("item " .. itemID)
end

local function Recalc()
    if not lootOpen or not DB then return end
    api = api or ns.GameAPI()
    local loot = ns.ScanLoot(api)
    local bags = loot and ns.ScanBags(api)
    if not (loot and bags) then
        -- Item data not loaded yet; GET_ITEM_INFO_RECEIVED will bring us back.
        ns.Card.Hide()
        return
    end
    local swap = ns.ChooseSwap(loot, bags, { threshold = DB.threshold, protected = DB.protected })
    if swap then ns.Card.Show(swap) else ns.Card.Hide() end
end

-- Several events often fire in the same frame; recalculate once, next frame.
local function QueueRecalc()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        Recalc()
    end)
end

ns.Card.onProtect = function(itemID)
    DB.protected[itemID] = true
    Print("will never suggest " .. ItemLink(itemID))
    Recalc()
end

------------------------------------------------------------------------
-- /wed demo: shows each card state with sample items
------------------------------------------------------------------------

local function DemoItem(itemID, name, quality, count, maxStack)
    local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local realName, link = GetItemInfo(itemID)
    return {
        itemID = itemID, name = realName or name, link = link, icon = GetIcon and GetIcon(itemID),
        quality = quality, count = count or 1, maxStack = maxStack or 1,
    }
end

local function DemoSwaps()
    local stone = DemoItem(2835, "Rough Stone", 1, 3, 20)
    return {
        {
            state = "worth",
            drop = stone, dropValue = 30, dropSource = "vendor",
            loot = DemoItem(1529, "Jade", 2), lootCount = 1, lootValue = 41320, lootSource = "AH",
            gain = 41290,
        },
        {
            state = "notworth",
            drop = DemoItem(4371, "Bronze Tube", 1), dropValue = 200, dropSource = "vendor",
            loot = DemoItem(2589, "Linen Cloth", 1, 1, 20), lootCount = 1, lootValue = 13, lootSource = "vendor",
            gain = -187, fullStackValue = 260,
        },
        {
            state = "musthave", mustHaveKind = "tool",
            drop = stone, dropValue = 30, dropSource = "vendor",
            loot = DemoItem(6256, "Fishing Pole", 1), lootCount = 1, lootValue = 0, lootSource = "vendor",
        },
    }
end

local function Demo()
    demoStep = demoStep + 1
    local swaps = DemoSwaps()
    if demoStep > #swaps then
        demoStep = 0
        ns.Card.Hide()
        return
    end
    ns.Card.Show(swaps[demoStep], true)
end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------

local function Help()
    Print("commands:")
    print("  /wed protect <shift-click item> - never suggest dropping this item")
    print("  /wed unprotect <shift-click item> - allow it again")
    print("  /wed list - show your protected items")
    print("  /wed threshold <n> - AH price counts when it's at least n x the vendor price (now " .. DB.threshold .. ")")
    print("  /wed demo - preview the card (run again to see the next state)")
end

local function Slash(msg)
    if not DB then return end
    local c = ns.ParseSlash(msg)
    if c.cmd == "protect" or c.cmd == "unprotect" then
        if not c.itemID then
            Print("usage: /wed " .. c.cmd .. " <shift-click an item>")
            return
        end
        DB.protected[c.itemID] = (c.cmd == "protect") or nil
        Print((c.cmd == "protect" and "will never suggest " or "may suggest again: ") .. ItemLink(c.itemID))
        if lootOpen then Recalc() end
    elseif c.cmd == "list" then
        local any = false
        for itemID in pairs(DB.protected) do
            if not any then Print("protected items:") end
            any = true
            print("  " .. ItemLink(itemID))
        end
        if not any then Print("No protected items.") end
    elseif c.cmd == "threshold" then
        if c.number and c.number >= 1 then
            DB.threshold = c.number
            if lootOpen then Recalc() end
        end
        Print("AH price counts when it's at least " .. DB.threshold .. "x the vendor price.")
    elseif c.cmd == "demo" then
        Demo()
    else
        Help()
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("LOOT_OPENED")
events:RegisterEvent("LOOT_SLOT_CLEARED")
events:RegisterEvent("LOOT_CLOSED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        WiseEconomicDecisionsDB = WiseEconomicDecisionsDB or {}
        DB = WiseEconomicDecisionsDB
        DB.protected = DB.protected or {}
        DB.threshold = DB.threshold or 5
        SLASH_WISEECONOMICDECISIONS1 = "/wed"
        SlashCmdList.WISEECONOMICDECISIONS = Slash
    elseif event == "LOOT_OPENED" then
        lootOpen = true
        demoStep = 0
        QueueRecalc()
    elseif event == "LOOT_CLOSED" then
        lootOpen = false
        ns.Card.Hide()
    elseif lootOpen then
        QueueRecalc()
    end
end)
