# Wise Economic Decisions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW Forever addon that, when loot won't fit in full bags, shows a swap card next to the loot window telling you which bag item to drop and how much gold you gain (or lose) by doing so.

**Architecture:** The addon has three layers. Pure-Lua modules (`Data`, `Value`, `Swap`, `Commands`) hold every decision and are tested outside the game with `luajit`. `Scan` turns game API calls into plain item records through an injectable `api` table, so it's tested with fakes too. `Card` (UI) and `WiseEconomicDecisions.lua` (events, SavedVariables, slash commands) wire everything into the game and are verified by syntax check plus an in-game checklist.

**Tech Stack:** Lua 5.1 / LuaJIT (WoW client), WoW Forever modern API (`C_Container`, `C_Item`), Auctionator `API.v1` (optional), `luajit` for tests.

**Spec:** `docs/superpowers/specs/2026-11-11-wise-economic-decisions-design.md`

## Global Constraints

- Target WoW Forever. TOC `## Interface: 11507, 11508, 16001`. Install path `_forever_/Interface/AddOns/WiseEconomicDecisions/`.
- `## OptionalDeps: Auctionator`. Without Auctionator the addon works on vendor prices only and never errors.
- The addon never deletes, moves, vendors, or loots anything. It only shows a suggestion.
- AH price counts only if `ah >= threshold × vendor`, default threshold **5**. The value used is then `math.floor(ah × 0.95)`. Bound items (soulbound bag items and bind-on-pickup loot) always use the vendor price.
- Pure modules (`Data.lua`, `Value.lua`, `Swap.lua`, `Commands.lua`) make no WoW API calls. Each loads via `local _, ns = ...`.
- Tests run from the repo root: `for f in tests/*_test.lua; do luajit "$f" || exit 1; done`.
- Slash command `/wed`. SavedVariables `WiseEconomicDecisionsDB` (account-wide) = `{ protected = { [itemID] = true }, threshold = 5 }`.
- All money is in copper (integers).
- In-game copy (ASCII only, because the default game font lacks `↓`, `−` and `—`): headers `Suggested swap` / `Not worth it` / `Make room for this`; middle line `Drop, then loot:`; value lines `vendor: <money>` / `AH: <money>`; stack note `full stack (<maxStack>): <money>`; totals `You gain +<money>` / `You lose -<money>`; must-have line `Quest item - your cheapest item to drop`, `Key - your cheapest item to drop`, or `Profession tool - your cheapest item to drop`; button `Never suggest this`. Money is formatted with `GetCoinTextureString`.

## Review Focus

1. **Item data not cached yet** (first loot of an item this session): the card must not show a partial or wrong suggestion. It stays hidden and recalculates when the data arrives. Pinned in Task 4 (`ScanLoot`/`ScanBags` return `nil, "pending"`).
2. **Group loot with locked slots** (someone else's item, or one waiting on a roll): locked slots are not "blocked loot" and never trigger the card. Pinned in Task 4.
3. **Coin and currency slots in the loot window**: these never need a bag slot and are skipped. Pinned in Task 4.
4. **Every possible drop is protected, or sits in a bag that can't hold the loot**: `ChooseSwap` returns `nil` and the card hides, including right after "Never suggest this" protects the last candidate. Pinned in Task 2.
5. **Another addon replaces the loot frame** (Blizzard `LootFrame` not shown): the card anchors to a fallback position and never errors. Pinned in Task 5 by the in-game checklist item.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `WiseEconomicDecisions.toc` | Load order: `Data.lua`, `Value.lua`, `Swap.lua`, `Commands.lua`, `Scan.lua`, `Card.lua`, `WiseEconomicDecisions.lua` |
| `Data.lua` | Item-ID lists: profession tools, teleport items, soul shard; class/subclass constants |
| `Value.lua` | `UnitValue`, `StackValue`, `ProtectionReason`, `MustHaveKind` |
| `Swap.lua` | `CanHold`, `Leftover`, `ChooseSwap` |
| `Commands.lua` | `ParseSlash`, `ItemIDFromLink` |
| `Scan.lua` | `ScanLoot(api)`, `ScanBags(api)`, `GameAPI()` builds the real `api` table |
| `Card.lua` | The swap card frame: `ns.Card.Show(swap)`, `ns.Card.Hide()` |
| `WiseEconomicDecisions.lua` | DB init, slash commands, events, `Recalc()` |
| `tests/helper.lua`, `tests/*_test.lua` | Test loader, assertions, fake item builder |

### Item record (shared shape: produced by `Scan`, consumed by `Value`/`Swap`, built by `tests/helper.lua`)

```lua
{
  itemID = 2589, link = "|cff...|Hitem:2589::|h[Linen Cloth]|h|r",
  name = "Linen Cloth", icon = 132889, quality = 1,
  count = 5,          -- stack count (bag) or quantity (loot)
  maxStack = 20,
  vendor = 13,        -- copper per unit, 0 if none
  ah = nil,           -- copper per unit from Auctionator, or nil
  bound = false,
  family = 0,         -- GetItemFamily bitmask, 0 = goes in general bags only
  classID = 7, subclassID = 5,
  isQuest = false,    -- quest class, quest item flag, or starts a quest
  -- bag items only:  bag = 0, slot = 3
  -- loot items only: lootSlot = 2
}
```

### Container record (`ScanBags` result is an array of these, backpack first, then bags 1–4)

```lua
{ bag = 1, family = 32, freeSlots = 2, items = { <item record>, ... } }
-- family 0 = general bag (holds anything); non-zero = special bag type bitmask
```

### Swap record (`ChooseSwap` result, consumed by `Card`)

```lua
{
  state = "worth" | "notworth" | "musthave",
  drop = <bag item record>, dropValue = 1200, dropSource = "vendor" | "AH",
  loot = <loot item record>, lootCount = 1, -- units of the loot that won't fit
  lootValue = 95000, lootSource = "vendor" | "AH",
  gain = 93800,                -- lootValue - dropValue (nil when state == "musthave")
  fullStackValue = nil,        -- unit value × maxStack when loot.maxStack > 1
  mustHaveKind = nil,          -- "quest" | "key" | "tool" when state == "musthave"
}
```

---

### Task 1: Project scaffold, item data, and valuation

**Files:**
- Create: `WiseEconomicDecisions.toc`, `.gitignore`, `LICENSE`, `Data.lua`, `Value.lua`
- Test: `tests/helper.lua`, `tests/value_test.lua`

**Interfaces:**
- Produces:
  - `ns.Data.TOOLS`, `ns.Data.TELEPORTS`: sets `{ [itemID] = true }`. `ns.Data.SOUL_SHARD = 6265`. `ns.Data.CLASS = { WEAPON = 2, PROJECTILE = 6, TRADEGOODS = 7, QUEST = 12, KEY = 13 }`. `ns.Data.FISHING_POLE_SUBCLASS = 20`.
  - `ns.UnitValue(item, threshold) -> copper:number, source:"vendor"|"AH"`
  - `ns.StackValue(item, threshold) -> copper:number, source` (unit × `item.count`)
  - `ns.ProtectionReason(item, userProtected, threshold) -> "user"|"tool"|"quest"|"teleport"|"key"|"ammo"|"soulshard"|"novalue"|nil` (checked in that order)
  - `ns.MustHaveKind(item) -> "quest"|"key"|"tool"|nil`
  - `tests/helper.lua` returns `T` with `T.load(files) -> ns`, `T.eq(name, got, want)` (exits 1 on failure), `T.item(overrides) -> item record` (defaults: `itemID=1, count=1, maxStack=1, vendor=0, family=0, classID=15, subclassID=0, bound=false, isQuest=false, name="Item", quality=1, icon=0`)

- [ ] **Step 1: Scaffold.** Run `git init`. Write `.gitignore` with `.DS_Store`, `*.zip`, `.superpowers/`. Copy `LICENSE` from `../waylaid-crates-made-easy/LICENSE`. Write the TOC:

```
## Interface: 11507, 11508, 16001
## Title: Wise Economic Decisions
## Notes: When your bags are full, suggests which item to drop to make the most gold from your loot.
## Author: lucas
## Version: 1.0.0
## OptionalDeps: Auctionator
## SavedVariables: WiseEconomicDecisionsDB

Data.lua
Value.lua
Swap.lua
Commands.lua
Scan.lua
Card.lua
WiseEconomicDecisions.lua
```

- [ ] **Step 2: Write `tests/helper.lua` and the failing `tests/value_test.lua`**

```lua
-- tests/value_test.lua  (run from repo root: luajit tests/value_test.lua)
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
T.eq("user",          ns.ProtectionReason(I{ itemID=2589, vendor=13 }, { [2589]=true }, 5), "user")
T.eq("enchant rod",   ns.ProtectionReason(I{ itemID=6218, vendor=25 }, none, 5), "tool")
T.eq("any fishing pole", ns.ProtectionReason(I{ itemID=999999, vendor=5, classID=2, subclassID=20 }, none, 5), "tool")
T.eq("quest class",   ns.ProtectionReason(I{ classID=12 }, none, 5), "quest")
T.eq("starts quest",  ns.ProtectionReason(I{ vendor=50, isQuest=true }, none, 5), "quest")
T.eq("hearthstone",   ns.ProtectionReason(I{ itemID=6948 }, none, 5), "teleport")
T.eq("key",           ns.ProtectionReason(I{ classID=13 }, none, 5), "key")
T.eq("ammo",          ns.ProtectionReason(I{ classID=6, vendor=1 }, none, 5), "ammo")
T.eq("soul shard",    ns.ProtectionReason(I{ itemID=6265 }, none, 5), "soulshard")
T.eq("no value",      ns.ProtectionReason(I{ vendor=0 }, none, 5), "novalue")
T.eq("bound, ah only",ns.ProtectionReason(I{ vendor=0, ah=5000, bound=true }, none, 5), "novalue")
T.eq("reagent ok",    ns.ProtectionReason(I{ classID=7, vendor=13 }, none, 5), nil)

-- MustHaveKind
T.eq("musthave quest", ns.MustHaveKind(I{ isQuest=true }), "quest")
T.eq("musthave key",   ns.MustHaveKind(I{ classID=13 }), "key")
T.eq("musthave tool",  ns.MustHaveKind(I{ itemID=2901 }), "tool")
T.eq("hearth not musthave", ns.MustHaveKind(I{ itemID=6948 }), nil)
T.eq("ammo not musthave",   ns.MustHaveKind(I{ classID=6 }), nil)
print("value_test: all passed")
```

`T.eq` compares deeply (tables by key/value, `nil` equals `nil`), prints `PASS <name>` or `FAIL <name>: got <x> want <y>`, and calls `os.exit(1)` on failure. `T.load` creates `ns = {}`, then runs `assert(loadfile(f))("WiseEconomicDecisions", ns)` for each file and returns `ns`.

- [ ] **Step 3: Run it and confirm it fails.** Run `luajit tests/value_test.lua`. Expected: error `cannot open Data.lua`.

- [ ] **Step 4: Implement `Data.lua` and `Value.lua`.** Fill the `Data.lua` lists with these IDs, and check each one on Wowhead Classic before committing:
  - **TOOLS:**
    - fishing poles 6256, 6365, 6366, 6367, 12225, 19022, 19970
    - Copper Rod 6217, and the Runed rods 6218, 6339, 11130, 11145, 16207
    - Mining Pick 2901
    - Skinning Knife 7005, Finkle's Skinner 12709, Zulian Slicer 19901
    - Blacksmith Hammer 5956
    - Arclight Spanner 6219, Gyromatic Micro-Adjustor 10498
    - Philosopher's Stone 9149
  - **TELEPORTS:**
    - Hearthstone 6948
    - Ultrasafe Transporter: Gadgetzan 18986, and Dimensional Ripper - Everlook 18984

  The protection order is fixed by the Interfaces block. `"novalue"` means `UnitValue(item, threshold) == 0`. `"tool"` matches a TOOLS item ID, or `classID == 2 and subclassID == 20`. `"quest"` matches `isQuest`, or `classID == 12`.

- [ ] **Step 5: Run it and confirm it passes.** Run `luajit tests/value_test.lua`. Expected: every line `PASS`, then `value_test: all passed`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore LICENSE WiseEconomicDecisions.toc Data.lua Value.lua tests/helper.lua tests/value_test.lua
git commit -m "Add scaffold, item data and valuation rules"
```

---

### Task 2: Fit check and swap selection

**Files:**
- Create: `Swap.lua`
- Test: `tests/swap_test.lua`

**Interfaces:**
- Consumes: `ns.UnitValue`, `ns.StackValue`, `ns.ProtectionReason`, `ns.MustHaveKind` (Task 1). Item, container, and swap records (File Structure).
- Produces:
  - `ns.CanHold(bagFamily:number, itemFamily:number) -> boolean`. True if `bagFamily == 0` or `bit.band(bagFamily, itemFamily) ~= 0`.
  - `ns.Leftover(lootItem, containers) -> number`: units that won't fit.
  - `ns.ChooseSwap(lootItems, containers, opts) -> swap record | nil`, where `opts = { threshold = number, protected = { [itemID] = true } }`.

**Algorithm for `ChooseSwap`** (the signature leaves room for choices, so the rules are fixed here):
1. **Find blocked loot.** Blocked loot = loot items with `Leftover > 0`. Use `lootCount = leftover`. If nothing is blocked, return `nil`.
2. **List the candidates.** For a blocked loot item L, the candidates are bag items that pass all three checks:
   - `ProtectionReason == nil`
   - their container satisfies `CanHold(container.family, L.family)`
   - `itemID ~= L.itemID`
3. **Must-have loot.** If any blocked L has a `MustHaveKind`, take the first such L in loot order that has at least one candidate. Pick its candidate with the lowest `StackValue`, then return `state = "musthave"`, `gain = nil`, and `mustHaveKind`.
4. **Otherwise, pick the best gain.** Over every (L, candidate) pair, `gain = UnitValue(L) × lootCount − StackValue(candidate)`. Pick the highest gain. On a tie, the first pair wins, in loot order and then container/item order. Return `state = "worth"` if `gain > 0`, and `"notworth"` otherwise.
5. **Stack note.** `fullStackValue = UnitValue(L) × L.maxStack` when `L.maxStack > 1`. Otherwise it's `nil`.
6. **No candidates.** If no pair exists, return `nil`.

**`Leftover`:** Start with `L.count`. First subtract the room left in existing stacks of the same `itemID` (`maxStack − count` each), but only in containers that `CanHold`. Then subtract `freeSlots × maxStack` for each container that `CanHold`. The result never goes below 0.

- [ ] **Step 1: Write the failing `tests/swap_test.lua`**

```lua
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
print("swap_test: all passed")
```

- [ ] **Step 2: Run it and confirm it fails.** Run `luajit tests/swap_test.lua`. Expected: error `cannot open Swap.lua`.
- [ ] **Step 3: Implement `Swap.lua`** following the algorithm above.
- [ ] **Step 4: Run both test files and confirm they pass.** Run `for f in tests/*_test.lua; do luajit "$f" || exit 1; done`. Expected: both end with `all passed`.
- [ ] **Step 5: Commit.** Run `git add Swap.lua tests/swap_test.lua && git commit -m "Add fit check and swap selection"`.

---

### Task 3: Slash command parsing

**Files:**
- Create: `Commands.lua`
- Test: `tests/commands_test.lua`

**Interfaces:**
- Produces:
  - `ns.ItemIDFromLink(text) -> number|nil` (first `item:(%d+)`)
  - `ns.ParseSlash(msg) -> { cmd = "help"|"protect"|"unprotect"|"list"|"threshold"|"demo", itemID = number|nil, number = number|nil }`. The command word is case-insensitive. An unknown or empty command becomes `"help"`.

- [ ] **Step 1: Write the failing test**

```lua
local T = dofile("tests/helper.lua")
local ns = T.load({ "Commands.lua" })
local link = "|cffffffff|Hitem:6948::::::::60:::::|h[Hearthstone]|h|r"
T.eq("link id",        ns.ItemIDFromLink(link), 6948)
T.eq("no link",        ns.ItemIDFromLink("hello"), nil)
T.eq("empty -> help",  ns.ParseSlash(""), { cmd = "help" })
T.eq("unknown -> help",ns.ParseSlash("foo"), { cmd = "help" })
T.eq("protect",        ns.ParseSlash("protect " .. link), { cmd = "protect", itemID = 6948 })
T.eq("unprotect",      ns.ParseSlash("unprotect " .. link), { cmd = "unprotect", itemID = 6948 })
T.eq("list caps",      ns.ParseSlash("LIST"), { cmd = "list" })
T.eq("threshold",      ns.ParseSlash("threshold 10"), { cmd = "threshold", number = 10 })
T.eq("threshold bad",  ns.ParseSlash("threshold abc"), { cmd = "threshold" })
T.eq("demo",           ns.ParseSlash("demo"), { cmd = "demo" })
print("commands_test: all passed")
```

- [ ] **Step 2: Run it and confirm it fails.** Run `luajit tests/commands_test.lua`. Expected: error `cannot open Commands.lua`.
- [ ] **Step 3: Implement `Commands.lua`.**
- [ ] **Step 4: Run it and confirm it passes.** Run `luajit tests/commands_test.lua`. Expected: `commands_test: all passed`.
- [ ] **Step 5: Commit.** Run `git add Commands.lua tests/commands_test.lua && git commit -m "Add slash command parsing"`.

---

### Task 4: Reading loot and bags from the game

**Files:**
- Create: `Scan.lua`
- Test: `tests/scan_test.lua`

**Interfaces:**
- Consumes: the item and container record shapes. `ns.ItemIDFromLink` (Task 3).
- Produces:
  - `ns.ScanLoot(api) -> items | nil, "pending"`
  - `ns.ScanBags(api) -> containers | nil, "pending"`
  - `ns.GameAPI() -> api` (the real implementation)
- `api` table, which the fakes in the tests implement:

| Field | Returns / Real implementation |
|-------|-------------------------------|
| `GetNumLootItems()` | number |
| `IsItemSlot(i)` | boolean. Real: `GetLootSlotType(i) == Enum.LootSlotType.Item`, falling back to `LOOT_SLOT_ITEM` |
| `GetLootSlotInfo(i)` | `texture, name, quantity, currencyID, quality, locked, isQuestItem, questID` |
| `GetLootSlotLink(i)` | link or nil |
| `GetItemInfo(linkOrID)` | the full classic return list; we read `[8]` maxStack, `[10]` texture, `[11]` sellPrice, `[12]` classID, `[13]` subclassID, `[14]` bindType. Returns nil if not cached. Real: `C_Item.GetItemInfo or GetItemInfo` |
| `RequestLoad(itemID)` | Real: `C_Item.RequestLoadItemDataByID` |
| `GetItemFamily(linkOrID)` | number. Real: `C_Item.GetItemFamily or GetItemFamily` |
| `GetAuctionPrice(itemID)` | number or nil. Real: `pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "WiseEconomicDecisions", itemID)` when Auctionator is loaded, else nil |
| `GetContainerNumSlots(bag)` | number. Real: `C_Container` version |
| `GetContainerNumFreeSlots(bag)` | `free, family`. Real: `C_Container` version |
| `GetContainerItemInfo(bag, slot)` | `{ itemID, stackCount, hyperlink, iconFileID, quality, isBound }` or nil. Real: `C_Container` version |
| `GetContainerItemQuestInfo(bag, slot)` | `{ isQuestItem, questID }`. Real: `C_Container` version |

- **Loot rules:** skip non-item slots (coins and currency), slots with `locked == true`, and slots with no link. Set `isQuest = isQuestItem or questID ~= nil`, `bound = (bindType == 1)`, and `lootSlot = i`.
- **Bag rules:** read bags 0–4. Skip a bag where `GetContainerNumSlots == 0`. Set `bound = info.isBound` and `isQuest = q.isQuestItem or q.questID ~= nil`.
- **Uncached items:** if `GetItemInfo` returns nil for any item, call `RequestLoad(itemID)` for each such item and return `nil, "pending"`.

- [ ] **Step 1: Write the failing `tests/scan_test.lua`.** Use a `fakeAPI(spec)` built from plain tables. Assertions:
  - **Loot with three slots:**
    - coin slot (`IsItemSlot` false): skipped
    - locked item: skipped
    - Linen Cloth ×5: one item `{ itemID=2589, count=5, maxStack=20, vendor=13, lootSlot=3 }`
  - **Bind-on-pickup:** loot with `bindType=1` gives `bound == true`.
  - **Quest flags:** loot with `questID=123` gives `isQuest == true`.
  - **Auctionator missing:** with `GetAuctionPrice` returning nil, `ah == nil` and nothing errors.
  - **Uncached loot:** a loot item whose `GetItemInfo` returns nil makes `ScanLoot` return `nil, "pending"`, and `RequestLoad` gets that itemID.
  - **Bags:** backpack with 1 free slot and family 0, plus bag 1 that's an herb bag (family 32) with Peacebloom ×3. `ScanBags` returns two containers. The second is `{ bag=1, family=32, freeSlots=0 }` and its one item has `count=3, bag=1, slot=1`.
  - **Bag that isn't there:** bag 2 has `GetContainerNumSlots == 0` and isn't in the result.
  - **Uncached bag item:** makes `ScanBags` return `nil, "pending"`.
- [ ] **Step 2: Run it and confirm it fails.** Run `luajit tests/scan_test.lua`. Expected: error `cannot open Scan.lua`.
- [ ] **Step 3: Implement `Scan.lua`.** `ScanLoot` and `ScanBags` get every value through `api`. `GameAPI()` is the only function that touches WoW globals, and it runs only when called, so loading the file under `luajit` doesn't error.
- [ ] **Step 4: Run all tests and confirm they pass.** Run `for f in tests/*_test.lua; do luajit "$f" || exit 1; done`. Expected: all four files end with `all passed`.
- [ ] **Step 5: Commit.** Run `git add Scan.lua tests/scan_test.lua && git commit -m "Add loot and bag scanning"`.

---

### Task 5: The swap card, slash commands, and event wiring

**Files:**
- Create: `Card.lua`, `WiseEconomicDecisions.lua`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `ns.Card.Show(swap)`
  - `ns.Card.Hide()`
  - `ns.Card.onProtect`, a function set by the main file, called as `onProtect(itemID)`

**`Card.lua`** follows the approved mockup (layout C, three states, in the spec's "The card" section):
- **Frame:** named `WiseEconomicDecisionsCard`, parent `UIParent`, `BackdropTemplate`, a dark tooltip-style backdrop, width about 240.
- **Rows, top to bottom:**
  1. Header in gold. The text is `Not worth it` for `notworth`, otherwise as in Global Constraints.
  2. Drop row: a 30px icon button with a stack count, the name in `ITEM_QUALITY_COLORS[quality]`, and the value line.
  3. `Drop, then loot:`
  4. Loot row: icon, name, value line, and the stack note when `fullStackValue` is set.
  5. A divider, then the total line. Green `You gain +` when `worth`, red `You lose -` when `notworth`, the must-have line in gold when `musthave`.
  6. The `Never suggest this` button (`UIPanelButtonTemplate`), which calls `onProtect(swap.drop.itemID)`.
- **Values:** pass the value line `lootValue` (the leftover's total). For `notworth`, show the loss as `GetCoinTextureString(-gain)` after the `-`.
- **Tooltips:** hovering either icon shows `GameTooltip:SetHyperlink(item.link)`.
- **Anchoring:** if `LootFrame` exists and is shown, put the card's `TOPLEFT` on `LootFrame`'s `TOPRIGHT` with a 4px gap. Otherwise anchor `LEFT` to `UIParent` `CENTER` with offset `(150, 0)`.

**`WiseEconomicDecisions.lua`:**
- **On `ADDON_LOADED`** (for this addon), set `WiseEconomicDecisionsDB = WiseEconomicDecisionsDB or {}`, then fill in defaults `protected = {}` and `threshold = 5`.
- **Events:**
  - `LOOT_OPENED` sets `lootOpen = true` and calls `Recalc()`.
  - `LOOT_SLOT_CLEARED`, `BAG_UPDATE_DELAYED`, and `GET_ITEM_INFO_RECEIVED` call `Recalc()` only while `lootOpen`.
  - `LOOT_CLOSED` sets `lootOpen = false` and calls `Card.Hide()`.
  - Coalesce calls so that several events in one frame lead to one `Recalc` on the next frame (`C_Timer.After(0, ...)` behind a pending flag).
- **`Recalc()`:** call `ScanLoot` and `ScanBags` with `GameAPI()`. If either is pending, `Card.Hide()` and stop. The `GET_ITEM_INFO_RECEIVED` event re-runs it. Otherwise call `ChooseSwap(loot, bags, { threshold = DB.threshold, protected = DB.protected })` and show the swap, or hide the card if it's `nil`.
- **`onProtect(itemID)`:** set `DB.protected[itemID] = true`, print `Wise Economic Decisions: will never suggest <link>`, then `Recalc()`.
- **`/wed`** goes through `ns.ParseSlash`:
  - `help` prints the four commands.
  - `protect` and `unprotect` change `DB.protected` and print the change. Without a link, they print a usage line.
  - `list` prints each protected item as a link (`GetItemInfo` returns the link, with the ID as a fallback), or `No protected items.`
  - `threshold` sets `DB.threshold` when the number is at least 1, otherwise prints the current value.
  - `demo` cycles the card through `worth`, `notworth`, and `musthave` using hard-coded swap records built from common items with real icons (such as Linen Cloth 2589), anchored with the fallback. `LOOT_CLOSED` won't hide it, so the next `/wed demo` after `musthave` hides it.

- [ ] **Step 1: Implement `Card.lua`** as described above.
- [ ] **Step 2: Implement `WiseEconomicDecisions.lua`** as described above.
- [ ] **Step 3: Syntax check and tests.** Run `for f in *.lua; do luajit -bl "$f" > /dev/null || echo "SYNTAX $f"; done; for f in tests/*_test.lua; do luajit "$f" || exit 1; done`. Expected: no `SYNTAX` lines, and every test file ends with `all passed`.
- [ ] **Step 4: Commit.** Run `git add Card.lua WiseEconomicDecisions.lua && git commit -m "Add swap card, slash commands and loot event wiring"`.
- [ ] **Step 5: In-game checklist.** Do this by hand. The user plays and an agent can't, so hand the list to the user.
  1. `/wed demo` three times shows all three states and matches the mockup. A fourth time hides the card.
  2. With full bags, loot a mob with a cheap grey in your bags. The card appears to the right of the loot window with the right gain.
  3. Loot something with free bag space. No card.
  4. Click `Never suggest this`. The item is protected and the card recalculates or hides. `/wed list` shows the item.
  5. Loot a quest item with full bags. The card shows `Make room for this`.
  6. In a group, a locked or round-robin item with full bags doesn't trigger the card.
  7. Disable Auctionator and `/reload`. There are no errors and every value line says `vendor`.
  8. With a replacement loot addon enabled, if you use one, the card appears at the fallback position without errors.

---

### Task 6: README, changelog, packaging

**Files:**
- Create: `README.md`, `CHANGELOG.md`, `.pkgmeta`

- [ ] **Step 1: Write the docs.** Model `README.md` on `../waylaid-crates-made-easy/README.md`, with the same sections and tone:
  - **What it does:** the three card states, how values are calculated (vendor price, and AH when it's at least 5× vendor, minus 5%; bound items use vendor only), and what's protected.
  - **Slash commands.**
  - **Installation:** into `_forever_/Interface/AddOns/WiseEconomicDecisions/`.
  - **Auctionator note.**
  - **Development:** the `luajit` test command.

  Screenshots are added by the user later. `CHANGELOG.md` gets a `## 1.0.0` entry. `.pkgmeta` is `package-as: WiseEconomicDecisions`, ignores `tests`, `screenshots`, `docs`, and `.superpowers`, and uses the same `manual-changelog` block as the sibling.
- [ ] **Step 2: Check the package.** Run `grep -n "package-as: WiseEconomicDecisions" .pkgmeta && grep -n "Version: 1.0.0" WiseEconomicDecisions.toc`. Expected: both match.
- [ ] **Step 3: Commit the docs, plus the spec and plan.** Run `git add README.md CHANGELOG.md .pkgmeta docs && git commit -m "Add README, changelog, packaging"`.
