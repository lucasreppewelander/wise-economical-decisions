# Wise Economic Decisions — Design

Date: 2026-11-11
Status: approved 2026-11-11

## Intent

When you're out looting with full bags, some loot won't fit. Right now you have to eyeball your bags and guess what's worth less than the thing on the floor. This addon makes that call for you: it looks at everything in your bags, finds the item whose loss costs you the least gold, and — if the loot is worth more — shows a small **suggestion** card next to the loot window: "drop this, loot that, you gain X".

It is a suggestion only. The addon never deletes, moves, or loots anything.

Success: you hit full bags, glance right of the loot window, and know in a second what to throw away and how much it's worth to do so — and it never tells you to throw away something you'd regret.

## Target platform

- **WoW Forever** (Classic-era game on the modern client API — `C_Item`, `C_Container`, etc.). Same target as the author's sibling addon `waylaid-crates-made-easy`.
- TOC `## Interface: 11507, 11508, 16001` (copied from the sibling addons).
- Install path: `World of Warcraft/_forever_/Interface/AddOns/WiseEconomicDecisions/`.
- **Auctionator is an optional dependency** (`## OptionalDeps: Auctionator`). Without it, vendor prices only.

## Goals

1. Detect when a loot window has at least one item that can't fit in your bags.
2. Work out the single best swap: which bag item to drop so that item can be looted.
3. Show it as a swap card next to the loot window (layout "C", below). If no swap makes money, still show the closest one, marked "Not worth it".
4. Never suggest a protected item.
5. Let you protect your own items from the card and from a slash command.

## Non-goals

- Deleting, vendoring, or moving items. No auto-anything.
- Bank and mail. (The keyring only counts as room for looted keys, never as a source of drops.)
- Group-loot roll windows (Need/Greed). Only the normal loot window.
- Money/coin loot (coins never need a bag slot).
- Tooltips or price display anywhere other than the card.
- Marking rows in the loot window itself. The dimmed "no room" rows in the mockups were only illustration (my call), and the addon doesn't change the loot frame.
- Judging whether gear is an upgrade for you.

## Anti-goals (would make it a failure even if it "works")

- Suggesting something you'd regret dropping: a profession tool, a quest item, your hearthstone, a key, ammo, soul shards, or anything you protected.
- Popping up when nothing is blocked. If your bags have room for everything, the card stays hidden.
- Throwing Lua errors (e.g. on uncached item data or when another loot addon replaces the loot frame).

## How value is calculated (decided with the user)

For any item, **unit value**:

- `vendor` = the item's vendor sell price (`sellPrice` from `GetItemInfo`).
- `ah` = Auctionator's price (`Auctionator.API.v1.GetAuctionPriceByItemID`), if Auctionator is loaded and has one.
- If `ah >= 5 × vendor` → unit value = `ah × 0.95` (AH cut), labeled **AH**.
- Otherwise → unit value = `vendor`, labeled **vendor**.
- The 5× threshold is user-configurable (`/wed threshold <n>`), default 5.

Rationale (user's words, paraphrased): vendor gold is guaranteed and preferred; AH only counts when it's way higher.

**Bound items use the vendor price only (my call).** A soulbound item, or bind-on-pickup loot, can't be sold on the AH, so Auctionator's price for its item ID doesn't apply. Bag items are checked with `C_Item.IsBound`. Bind-on-pickup loot is detected however the builder finds reliable, for example from the tooltip.

Edge cases (builder's call within this rule): if `vendor == 0` and `ah > 0`, AH counts (any positive AH is ≥ 5 × 0). Items with value 0 by both measures are protected (see below), not "free to drop".

**Stack value** = unit value × stack count. A stack of 3 linen is worth 3 × linen.

## When the card appears

- On `LOOT_OPENED`, and re-evaluated on `LOOT_SLOT_CLEARED` and `BAG_UPDATE_DELAYED` while the loot window is open. Hidden on `LOOT_CLOSED`.
- The card shows only if at least one loot slot holds an item that **won't fit** (see fit rules) **and** there is at least one valid swap (a non-protected candidate that frees a usable slot). Otherwise it's hidden.
- **Two states** (user's request):
  - **Worth it**: best gain > 0. Green "You gain" line.
  - **Not worth it**: no swap gains money. The card still shows the *closest* swap (the smallest loss), with a "Not worth it" header and the loss in red ("You lose − 3s 10c"). This lets you see how close it is and decide yourself.
  - **Make room for this** (user's choice): the blocked loot item is a quest item (including items that start a quest), a key, or a profession tool. These are always worth picking up, whatever their price. The card suggests the cheapest valid item to drop and shows no gain or loss line. This state takes priority over the other two: if any blocked loot item is in these categories, it's the one shown. If several are, the builder decides which comes first.
- A gain of exactly 0 counts as "not worth it" (my call).
- Hearthstones, teleport items, ammo, and soul shards in the loot use the normal value rules (my call). Only quest items, keys, and profession tools trigger "Make room for this".

## Fit rules — "won't fit" (my call, user didn't object)

A loot item fits without dropping anything if its whole quantity can go into existing partial stacks of the same item plus free slots in bags that accept it. Bag families matter (Classic special bags):

- A general bag slot accepts anything.
- A special bag (herb bag, enchanting bag, quiver, ammo pouch, soul bag…) only accepts items whose item family matches (`GetItemFamily` vs. the bag type from `C_Container.GetContainerNumFreeSlots`).

If only part of a loot stack fits, the leftover counts as blocked, and its loot value is the leftover quantity × unit value.

## Choosing the best swap

- Candidates: every non-protected item in the backpack and bags 1–4.
- A candidate is only valid for a given blocked loot item if dropping it frees a slot that the loot item can go into (dropping something from a herb bag doesn't help a sword).
- `gain = loot value − candidate stack value`.
- Across all (blocked loot item, valid candidate) pairs, pick the highest gain, even if it's negative. Show only that one.
- Stacking does **not** affect which swap is chosen. It only shows up as a side note on the card (the user's choice, see below).
- After you act (drop + loot), the events above re-run the calculation and the card shows the next best swap, or hides.

## Protected items — never suggested

Defaults (agreed with the user):

- **Profession tools**: fishing poles, enchanting rods (Runed Copper/Silver/Golden/Truesilver/Arcanite), Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight Spanner, Gyromatic Micro-Adjustor, and similar. Use a curated item-ID list; also treat any item of the Fishing Pole weapon subclass as a tool.
- **Quest items** (quest item class, and items that start a quest).
- **Hearthstone and other teleport items** (item-ID list).
- **Keys** (key item class).
- **Ammo** (projectile class) and **soul shards**.
- **Anything with no vendor price and no AH price.**

User-protected items:

- Stored by item ID, account-wide, in SavedVariables (my call).
- Added via the card's **"Never suggest this"** button, or `/wed protect <shift-clicked item link>`.
- Removed via `/wed unprotect <item link>`.
- Listed via `/wed list`.

Reagents are **not** protected — the user explicitly wants them suggested when dropping them gains money.

## The card (layout C — chosen by the user in a mockup)

Anchored to the right side of the loot window. Contents, top to bottom:

1. Header: **Suggested swap** (worth it), **Not worth it** (closest swap, still a loss), or **Make room for this** (must-have loot; no gain/loss line in this state).
2. Drop row: bag item icon (with stack count), name in item-quality color, value line `vendor · 12s` or `AH · 41g 32s`.
3. `↓ drop, then loot`
4. Loot row: loot item icon (with count), name in quality color, value line with its label.
   - **Stack side note** (user's request): if the loot item stacks (max stack > 1), add a small line such as `full stack (20): 20s` = unit value × max stack. It's shown for information only and never changes which swap is picked. It appears in both states (my call).
5. Divider, then **You gain + 41g 20s 05c** in green, or **You lose − 3s 10c** in red, with gold/silver/copper coin icons.
6. **Never suggest this** button (protects the drop item, then recalculates).

Hovering an icon shows the normal item tooltip (my call).

Look and feel: matches the standard game UI (dark backdrop, gold header text). Mockup lives at `.superpowers/brainstorm/*/content/suggestion-layout.html`, option C.

## Slash commands

`/wed` (prints help)
`/wed protect <item link>` · `/wed unprotect <item link>` · `/wed list`
`/wed threshold <n>` — AH must be at least n × vendor price to count (default 5)

## Project shape (follow `waylaid-crates-made-easy`)

- `WiseEconomicDecisions.toc`, main Lua file for events/UI, and a separate pure-Lua module for valuation, fit checks, and swap selection with no game API calls, so it can be tested with `luajit tests/*_test.lua` outside the game.
- `README.md`, `CHANGELOG.md`, `.pkgmeta`, `.gitignore` (include `.superpowers/`), license as in the sibling.

## Left to the builder

- Exact item-ID lists for profession tools and teleport items.
- How to detect "starts a quest" items.
- Handling of item data that isn't cached yet (`GET_ITEM_INFO_RECEIVED` / `Item:ContinueOnItemLoad`). Never show a wrong suggestion. Recalculate once the data arrives.
- What to do if another addon replaces the loot frame. Anchor to whatever frame is visible, or fall back to a sensible screen position, and never error.
- Tie-breaking between equal gains.
- Exact frame sizes, fonts, and textures.
