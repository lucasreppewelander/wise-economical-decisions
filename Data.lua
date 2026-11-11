-- Item lists and constants (pure data, no game API calls).

local _, ns = ...

local function Set(ids)
    local s = {}
    for _, id in ipairs(ids) do s[id] = true end
    return s
end

ns.Data = {
    -- Profession tools: never suggested as a drop, always worth making room for.
    TOOLS = Set({
        -- Fishing poles (any item of the Fishing Pole subclass counts too)
        6256,  -- Fishing Pole
        6365,  -- Strong Fishing Pole
        6366,  -- Darkwood Fishing Pole
        6367,  -- Big Iron Fishing Pole
        12225, -- Blump Family Fishing Pole
        19022, -- Nat Pagle's Extreme Angler FC-5000
        19970, -- Arcanite Fishing Pole
        -- Enchanting rods
        6217,  -- Copper Rod
        6218,  -- Runed Copper Rod
        6339,  -- Runed Silver Rod
        11130, -- Runed Golden Rod
        11145, -- Runed Truesilver Rod
        16207, -- Runed Arcanite Rod
        -- Gathering and crafting tools
        2901,  -- Mining Pick
        7005,  -- Skinning Knife
        19901, -- Zulian Slicer
        5956,  -- Blacksmith Hammer
        6219,  -- Arclight Spanner
        10498, -- Gyromatic Micro-Adjustor
        9149,  -- Philosopher's Stone
    }),

    -- Hearthstone and other teleport items
    TELEPORTS = Set({
        6948,  -- Hearthstone
        18986, -- Ultrasafe Transporter: Gadgetzan
        18984, -- Dimensional Ripper - Everlook
    }),

    SOUL_SHARD = 6265,

    CLASS = { WEAPON = 2, PROJECTILE = 6, TRADEGOODS = 7, QUEST = 12, KEY = 13 },
    FISHING_POLE_SUBCLASS = 20,
}
