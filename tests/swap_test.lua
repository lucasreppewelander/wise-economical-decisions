-- Run from repo root: luajit tests/swap_test.lua
local T = dofile("tests/helper.lua")
local ns = T.load({ "Data.lua", "Value.lua", "Swap.lua" })
local I = T.item
local opts = { threshold = 5, protected = {} }
local function bag(family, free, items) return { bag = 0, family = family, freeSlots = free, items = items } end

-- CanHold
T.eq("general holds anything", ns.CanHold(0, 32), true)
T.eq("herb bag holds herb",    ns.CanHold(32, 32), true)
T.eq("herb bag rejects sword", ns.CanHold(32, 0), false)
T.eq("quiver rejects herb",    ns.CanHold(1, 32), false)

-- Leftover
local linen = function(n) return I{ itemID=2589, count=n, maxStack=20, vendor=13 } end
T.eq("partial stack absorbs some", ns.Leftover(linen(5), { bag(0, 0, { linen(18) }) }), 3)
T.eq("free slot fits",             ns.Leftover(linen(5), { bag(0, 1, { linen(18) }) }), 0)
local herb = I{ itemID=765, count=2, maxStack=20, vendor=10, family=32 }
T.eq("herb into herb bag",         ns.Leftover(herb, { bag(0, 0, {}), bag(32, 1, {}) }), 0)
local sword = I{ itemID=100, vendor=500 }
T.eq("sword can't use herb bag",   ns.Leftover(sword, { bag(0, 0, {}), bag(32, 3, {}) }), 1)

-- ChooseSwap: worth it
local ring  = I{ itemID=200, vendor=1000, ah=100000, lootSlot=2 }
local scrap = I{ itemID=300, vendor=400, count=3 }
local cloth = I{ itemID=301, vendor=5000 }
local s = ns.ChooseSwap({ ring }, { bag(0, 0, { scrap, cloth }) }, opts)
T.eq("worth: state", s.state, "worth")
T.eq("worth: drops cheapest", s.drop.itemID, 300)
T.eq("worth: values", { s.lootValue, s.lootSource, s.dropValue, s.dropSource, s.gain }, { 95000, "AH", 1200, "vendor", 93800 })
T.eq("worth: ring has no stack note", s.fullStackValue, nil)

-- ChooseSwap: not worth it, closest swap, stack note
local tube = I{ itemID=400, vendor=200 }
s = ns.ChooseSwap({ linen(1) }, { bag(0, 0, { tube }) }, opts)
T.eq("notworth: state/gain/note", { s.state, s.gain, s.fullStackValue }, { "notworth", -187, 260 })

-- ChooseSwap: zero gain counts as not worth it
s = ns.ChooseSwap({ I{ itemID=500, vendor=200 } }, { bag(0, 0, { tube }) }, opts)
T.eq("zero gain is notworth", { s.state, s.gain }, { "notworth", 0 })

-- ChooseSwap: must-have beats a profitable swap
local paw = I{ itemID=600, classID=12, vendor=0, lootSlot=1 }
s = ns.ChooseSwap({ paw, ring }, { bag(0, 0, { scrap, cloth }) }, opts)
T.eq("musthave", { s.state, s.loot.itemID, s.drop.itemID, s.gain, s.mustHaveKind }, { "musthave", 600, 300, nil, "quest" })

-- Protected bag items are never dropped
local hearth = I{ itemID=6948, vendor=0 }
local rod    = I{ itemID=6218, vendor=1 }
s = ns.ChooseSwap({ ring }, { bag(0, 0, { hearth, rod, cloth }) }, opts)
T.eq("skips protected", s.drop.itemID, 301)
T.eq("all protected -> nil", ns.ChooseSwap({ ring }, { bag(0, 0, { hearth, rod }) }, opts), nil)
T.eq("user protected -> nil", ns.ChooseSwap({ ring }, { bag(0, 0, { cloth }) }, { threshold=5, protected={ [301]=true } }), nil)

-- Only candidates in bags that can hold the loot
local cheapHerb = I{ itemID=765, vendor=1, family=32 }
s = ns.ChooseSwap({ ring }, { bag(0, 0, { cloth }), bag(32, 0, { cheapHerb }) }, opts)
T.eq("ignores herb-bag candidate for ring", s.drop.itemID, 301)

-- Nothing blocked -> nil; same item never suggested as its own drop
T.eq("nothing blocked", ns.ChooseSwap({ ring }, { bag(0, 1, { cloth }) }, opts), nil)
T.eq("same item excluded", ns.ChooseSwap({ linen(5) }, { bag(0, 0, { linen(20) }) }, opts), nil)

-- Several blocked: highest gain pair
local ore = I{ itemID=700, vendor=3000, lootSlot=3 }
s = ns.ChooseSwap({ ore, ring }, { bag(0, 0, { scrap }) }, opts)
T.eq("best of several", s.loot.itemID, 200)
-- Keys go to the keyring (family 256): a key with keyring room isn't blocked
local key = I{ itemID=7146, classID=13, family=256 }
T.eq("key fits keyring", ns.ChooseSwap({ key }, { bag(0, 0, { cloth }), bag(256, 1, {}) }, opts), nil)
T.eq("keyring holds no sword", ns.Leftover(sword, { bag(0, 0, {}), bag(256, 4, {}) }), 1)

-- Must-have loot gets no stack note (its value is usually 0)
local stackQuest = I{ itemID=601, classID=12, vendor=0, maxStack=20 }
s = ns.ChooseSwap({ stackQuest }, { bag(0, 0, { scrap }) }, opts)
T.eq("musthave has no stack note", { s.state, s.fullStackValue }, { "musthave", nil })
print("swap_test: all passed")
