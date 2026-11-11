-- The swap card shown next to the loot window.

local _, ns = ...

local Card = {}
ns.Card = Card

local WIDTH = 240
local INNER = WIDTH - 20

local HEADERS = { worth = "Suggested swap", notworth = "Not worth it", musthave = "Make room for this" }
local MUST_LINES = {
    quest = "Quest item - your cheapest item to drop",
    key = "Key - your cheapest item to drop",
    tool = "Profession tool - your cheapest item to drop",
}
local MUST_LABELS = { quest = "quest item", key = "key", tool = "profession tool" }

local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function Money(copper)
    copper = math.floor(copper or 0)
    if copper <= 0 then return "0" .. COPPER_ICON end
    return GetCoinTextureString(copper)
end

local function SetQualityColor(fs, quality)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    if c then fs:SetTextColor(c.r, c.g, c.b) else fs:SetTextColor(1, 1, 1) end
end

local frame, current, isDemo

local function CreateItemRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(INNER, 32)

    local btn = CreateFrame("Button", nil, row)
    btn:SetSize(30, 30)
    btn:SetPoint("TOPLEFT")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints()
    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", -1, 1)
    btn:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.button = btn

    local function Line(font, anchor, y)
        local fs = row:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", anchor, anchor == btn and "TOPRIGHT" or "BOTTOMLEFT", anchor == btn and 6 or 0, y)
        fs:SetWidth(INNER - 36)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    row.name = Line("GameFontNormalSmall", btn, -1)
    row.value = Line("GameFontHighlightSmall", row.name, -2)
    row.value:SetTextColor(0.66, 0.61, 0.5)
    row.note = Line("GameFontDisableSmall", row.value, -2)
    row.note:SetTextColor(0.78, 0.73, 0.54)
    return row
end

local function FillRow(row, item, valueText, noteText)
    row.button.link = item.link
    row.button.icon:SetTexture(item.icon or 134400)
    row.button.count:SetText((item.count or 1) > 1 and item.count or "")
    row.name:SetText(item.name or "?")
    SetQualityColor(row.name, item.quality)
    row.value:SetText(valueText)
    row.note:SetText(noteText or "")
    row.note:SetShown(noteText ~= nil)
    row:SetHeight(noteText and 42 or 32)
end

local function Create()
    frame = CreateFrame("Frame", "WiseEconomicDecisionsCard", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.03, 0.02, 0.92)
    frame:SetBackdropBorderColor(0.6, 0.5, 0.3)
    frame:Hide()

    frame.header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.header:SetPoint("TOPLEFT", 10, -10)

    frame.dropRow = CreateItemRow(frame)
    frame.dropRow:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -6)

    frame.middle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.middle:SetPoint("TOPLEFT", frame.dropRow, "BOTTOMLEFT", 2, -3)
    frame.middle:SetText("Drop, then loot:")

    frame.lootRow = CreateItemRow(frame)
    frame.lootRow:SetPoint("TOPLEFT", frame.middle, "BOTTOMLEFT", -2, -4)

    frame.divider = frame:CreateTexture(nil, "ARTWORK")
    frame.divider:SetColorTexture(0.29, 0.25, 0.16, 1)
    frame.divider:SetSize(INNER, 1)
    frame.divider:SetPoint("TOPLEFT", frame.lootRow, "BOTTOMLEFT", 0, -4)

    frame.total = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.total:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, -5)
    frame.total:SetWidth(INNER)
    frame.total:SetJustifyH("LEFT")

    frame.protect = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.protect:SetSize(130, 20)
    frame.protect:SetPoint("TOPLEFT", frame.total, "BOTTOMLEFT", 0, -6)
    frame.protect:SetText("Never suggest this")
    frame.protect:SetScript("OnClick", function()
        if current and not isDemo and Card.onProtect then
            Card.onProtect(current.drop.itemID)
        end
    end)
end

local function Anchor(useFallback)
    frame:ClearAllPoints()
    if not useFallback and LootFrame and LootFrame:IsShown() then
        frame:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
    else
        frame:SetPoint("LEFT", UIParent, "CENTER", 150, 0)
    end
end

-- swap: a ChooseSwap record. demo: true for /wed demo (fallback anchor,
-- protect button disabled so sample items can't be protected by accident).
function Card.Show(swap, demo)
    if not frame then Create() end
    current, isDemo = swap, demo and true or false

    frame.header:SetText(HEADERS[swap.state] or "")
    if swap.state == "notworth" then
        frame.header:SetTextColor(1, 0.42, 0.42)
    else
        frame.header:SetTextColor(1, 0.82, 0)
    end

    FillRow(frame.dropRow, swap.drop, swap.dropSource .. ": " .. Money(swap.dropValue))

    local lootLine
    if swap.state == "musthave" then
        lootLine = MUST_LABELS[swap.mustHaveKind] or ""
    else
        lootLine = swap.lootSource .. ": " .. Money(swap.lootValue)
    end
    local note = swap.fullStackValue
        and ("full stack (" .. swap.loot.maxStack .. "): " .. Money(swap.fullStackValue)) or nil
    FillRow(frame.lootRow, swap.loot, lootLine, note)

    if swap.state == "worth" then
        frame.total:SetText("You gain +" .. Money(swap.gain))
        frame.total:SetTextColor(0.25, 1, 0.25)
    elseif swap.state == "notworth" then
        frame.total:SetText(swap.gain == 0 and "No gain" or ("You lose -" .. Money(-swap.gain)))
        frame.total:SetTextColor(1, 0.31, 0.31)
    else
        frame.total:SetText(MUST_LINES[swap.mustHaveKind] or "")
        frame.total:SetTextColor(1, 0.82, 0)
    end

    frame.protect:SetEnabled(not isDemo)
    frame:SetHeight(140 + frame.lootRow:GetHeight())
    Anchor(isDemo)
    frame:Show()
end

function Card.Hide()
    current = nil
    if frame then frame:Hide() end
end
