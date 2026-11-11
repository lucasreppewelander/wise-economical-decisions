-- Run from repo root: luajit tests/value_test.lua
local T = dofile("tests/helper.lua")
local ns = T.load({ "Data.lua", "Value.lua" })
local I = T.item

-- UnitValue / StackValue
T.eq("vendor only",        { ns.UnitValue(I{ vendor=100 }, 5) },               { 100, "vendor" })
T.eq("ah below 5x",        { ns.UnitValue(I{ vendor=100, ah=499 }, 5) },       { 100, "vendor" })
T.eq("ah at 5x, minus 5%", { ns.UnitValue(I{ vendor=100, ah=500 }, 5) },       { 475, "AH" })
T.eq("ah floors",          { ns.UnitValue(I{ vendor=1, ah=101 }, 5) },         { 95, "AH" })
T.eq("bound ignores ah",   { ns.UnitValue(I{ vendor=100, ah=10000, bound=true }, 5) }, { 100, "vendor" })
T.eq("no vendor, ah",      { ns.UnitValue(I{ vendor=0, ah=2000 }, 5) },        { 1900, "AH" })
T.eq("custom threshold",   { ns.UnitValue(I{ vendor=100, ah=600 }, 10) },      { 100, "vendor" })
T.eq("stack value",        { ns.StackValue(I{ vendor=100, count=3 }, 5) },     { 300, "vendor" })

-- ProtectionReason
local none = {}
T.eq("user",             ns.ProtectionReason(I{ itemID=2589, vendor=13 }, { [2589]=true }, 5), "user")
T.eq("enchant rod",      ns.ProtectionReason(I{ itemID=6218, vendor=25 }, none, 5), "tool")
T.eq("any fishing pole", ns.ProtectionReason(I{ itemID=999999, vendor=5, classID=2, subclassID=20 }, none, 5), "tool")
T.eq("quest class",      ns.ProtectionReason(I{ classID=12 }, none, 5), "quest")
T.eq("starts quest",     ns.ProtectionReason(I{ vendor=50, isQuest=true }, none, 5), "quest")
T.eq("hearthstone",      ns.ProtectionReason(I{ itemID=6948 }, none, 5), "teleport")
T.eq("key",              ns.ProtectionReason(I{ classID=13 }, none, 5), "key")
T.eq("ammo",             ns.ProtectionReason(I{ classID=6, vendor=1 }, none, 5), "ammo")
T.eq("soul shard",       ns.ProtectionReason(I{ itemID=6265 }, none, 5), "soulshard")
T.eq("no value",         ns.ProtectionReason(I{ vendor=0 }, none, 5), "novalue")
T.eq("bound, ah only",   ns.ProtectionReason(I{ vendor=0, ah=5000, bound=true }, none, 5), "novalue")
T.eq("being opened",     ns.ProtectionReason(I{ vendor=25, opening=true }, none, 5), "opening")
T.eq("reagent ok",       ns.ProtectionReason(I{ classID=7, vendor=13 }, none, 5), nil)

-- MustHaveKind
T.eq("musthave quest",      ns.MustHaveKind(I{ isQuest=true }), "quest")
T.eq("musthave key",        ns.MustHaveKind(I{ classID=13 }), "key")
T.eq("musthave tool",       ns.MustHaveKind(I{ itemID=2901 }), "tool")
T.eq("hearth not musthave", ns.MustHaveKind(I{ itemID=6948 }), nil)
T.eq("ammo not musthave",   ns.MustHaveKind(I{ classID=6 }), nil)
-- FormatMoney: own formatter (GetCoinTextureString doesn't exist on WoW Forever)
local G, S, C = ns.GOLD_ICON, ns.SILVER_ICON, ns.COPPER_ICON
T.eq("money gold",    ns.FormatMoney(412005), "41 " .. G .. " 20 " .. S .. " 05 " .. C)
T.eq("money silver",  ns.FormatMoney(187), "1 " .. S .. " 87 " .. C)
T.eq("money copper",  ns.FormatMoney(13), "13 " .. C)
T.eq("money zero",    ns.FormatMoney(0), "0 " .. C)
T.eq("money floors",  ns.FormatMoney(99.9), "99 " .. C)
T.eq("icons are textures", G:match("^|T.-|t$") ~= nil, true)
print("value_test: all passed")
