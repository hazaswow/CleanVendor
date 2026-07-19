# CleanVendor

A search panel attached to merchant windows for **WoW 3.3.5**, built and tested on **Ascension (Conquest of Azeroth)**. Find any item in seconds at those 100+ item vendors. Lightweight and standalone.

## Features

- **Search bar** matching item names **and tooltip content** (stats, effects, descriptions)
- **Filters**: weapons (**one-hand / two-hand / ranged** / by type: axes, swords…), armor by type (cloth, leather, mail, plate, shields), plus every other item category — category names come from the client itself, so they are always in your language
- **Red-gray tint** on combat gear you **cannot equip** (missing weapon/armor proficiency) — both in the list and on the native merchant grid
- **Quick buying** from the list: right-click = buy 1, **Shift+right-click = choose any amount** (automatically splits beyond stack size: ask for 300 potions and the addon chains the purchases)
- Full item tooltip on hover; Shift+left-click to link an item in chat
- Automatic **EN/FR localization** based on the client language

## Installation

1. Download the latest release zip (or `Code → Download ZIP`).
2. Extract it into `Interface/AddOns/`.
3. Make sure the folder is named exactly `CleanVendor` (rename it if it ends with `-main`).
4. Restart the game.

## Commands

| Command | Effect |
|---|---|
| `/cvd red` | Toggle the red tint on unequippable items |
| `/cvd` | Show help |

## Notes

- The tint only applies to combat-equippable gear (weapons, armor, jewelry). Cosmetic items, containers, consumables and recipes are never tinted.
- Unequippable detection uses the tooltip's red requirement lines — the same visual signal the game itself uses — so it works even on classless servers where the native `isUsable` flag reports nothing.

## Author

**Hazas**
