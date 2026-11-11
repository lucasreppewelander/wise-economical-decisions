# Wise Economic Decisions

A World of Warcraft Forever addon for looting with full bags. When an item in the loot window won't fit, it tells you which item in your bags to throw away and how much gold you gain by swapping.

A small card appears to the right of the loot window. It shows the item to drop and the item to loot, each with its icon, name and value, and what the swap gains or loses. It's only a suggestion. The addon never deletes, moves or loots anything.

## The card

The card only appears when something in the loot window doesn't fit in your bags. It shows one of three things:

- **Suggested swap:** the loot is worth more than the cheapest item you could drop. The gain is shown in green.
- **Not worth it:** no swap makes money. The card still shows the closest one, with the loss in red, so you can decide for yourself.
- **Make room for this:** the loot is a quest item, a key or a profession tool. These are always worth picking up, so the card suggests the cheapest item to drop.

If the loot stacks, the card also shows what a full stack would be worth, for example `full stack (20): 2s 60c`. This is only there to help you decide. It doesn't change which item is suggested.

When more than one item won't fit, the card shows the best swap. After you drop and loot, it moves on to the next one.

The addon understands special bags. Herbs can go in an herb bag and arrows in a quiver, and loot that tops up a stack you already have doesn't need a free slot.

## How items are valued

- An item's value is its **vendor sell price** × the stack size.
- If [Auctionator](https://www.curseforge.com/wow/addons/auctionator) has an auction house price that's **at least 5× the vendor price**, the addon uses the AH price minus the 5% auction house cut instead. You can change the 5× with `/wed threshold`.
- Soulbound and bind-on-pickup items always use the vendor price, because they can't be sold on the auction house.
- Each value on the card is labelled `vendor` or `AH`, so you can see which price was used.

## Never suggested

The addon never tells you to drop these:

- profession tools: fishing poles, enchanting rods, the mining pick, skinning knives, the blacksmith hammer, engineering tools and the Philosopher's Stone
- quest items, and items that start a quest
- your Hearthstone and other teleport items
- keys
- ammo and soul shards
- anything with no vendor price and no auction house price
- items you've protected yourself

Reagents can be suggested if dropping them makes you more money.

## Slash commands

- `/wed protect <shift-click item>`: never suggest dropping this item. The **Never suggest this** button on the card does the same.
- `/wed unprotect <shift-click item>`: allow it to be suggested again.
- `/wed list`: show your protected items. The list is shared by all your characters.
- `/wed threshold <n>`: the auction house price counts when it's at least n × the vendor price. The default is 5.
- `/wed demo`: preview the card. Run it again to see the next state.

## Installation

1. **[Download WiseEconomicDecisions.zip](https://github.com/lucasreppewelander/wise-economical-decisions/releases/latest/download/WiseEconomicDecisions.zip)**
2. Extract it into `World of Warcraft/_forever_/Interface/AddOns/`. You should end up with `AddOns/WiseEconomicDecisions/WiseEconomicDecisions.toc`.
3. Restart the game.

Don't use GitHub's green **Code → Download ZIP** button. It names the folder `wise-economical-decisions-main`, and WoW won't load the addon from a folder with that name.

For auction house prices, install [Auctionator](https://www.curseforge.com/wow/addons/auctionator) and run a scan at the auction house. Without it, the addon uses vendor prices only.

If the addon shows as out of date, tick **Load out of date AddOns** on the character select screen. You can also update the `## Interface:` line in `WiseEconomicDecisions.toc` to your client's version. Run `/dump select(4, GetBuildInfo())` in game to find it.

## Development

The pricing, fitting and swap logic has tests that run outside the game:

```sh
for f in tests/*_test.lua; do luajit "$f" || exit 1; done
```
