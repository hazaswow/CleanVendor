# Changelog

## 1.6
- Each list line now shows the item's **price** on the right, using **currency icons** instead of names: gold/silver/copper for money, and the icon returned by the merchant API for alternate currencies (Valor, Marks, emblems, honor…). Mixed money+token costs are supported.
- The **Alt+right-click amount prompt** now shows a **live total cost** (price × amount, with icons) that updates as you type. The total mirrors the real purchase logic, so lot-sold items (e.g. 5 per purchase) are counted per lot, not per unit.
- Item names in the list truncate before overlapping their price rather than colliding with it.
- Fixed alternate-currency prices not showing on Ascension/CoA: `GetMerchantItemCostInfo` returns the slot count as its third value there (`honor, arena, itemCount`), not the first as on stock 3.3.5.
- Added a hidden `/cvd diag N` command to inspect the merchant cost API for a given item index (kept for future exotic-currency debugging).

## 1.5
- The panel now sits on the LOW frame strata so it no longer covers interface windows such as the item appearance preview.
- Added a small options area at the bottom of the panel: toggle the red tint, and choose whether the native merchant grid is tinted too.
- Panel anchoring adjusted to CoA's compact merchant window (no more overlap).

## 1.4
- Amount prompt moved to **Alt+right-click** (the client appears to have its own native Shift+click "buy a stack" shortcut which bypassed and conflicted with our prompt; Shift+right-click on our list is now deliberately inert).
- The amount prompt now uses a homemade input window instead of the native StaticPopup system.
- Red tint darkened toward a desaturated dark red, and detection threshold tightened to reduce false positives.


## 1.3
- Added buy-by-amount: Shift+right-click a list line opens an amount prompt; purchases are automatically chained beyond stack size (safety cap: 1000).

## 1.2.1
- Tint restricted to combat-equippable gear only (cosmetics, containers, consumables and recipes are never tinted).

## 1.2
- Red tint now uses a semi-transparent overlay on top of the icon (shader desaturation neutralizes vertex color on some clients: icons went gray but never red).
- Reverted inline color-code detection (too many false positives on Ascension's custom tooltips).

## 1.1
- Unusable detection through tooltip red requirement lines (works on classless servers where the native isUsable flag reports nothing).
- Native grid tint deferred by one frame so third-party skins can no longer overwrite it.

## 1.0
- Initial release: search bar (name + tooltip text), category filters (weapons incl. one-hand/two-hand/ranged, armor types, all other classes), scrollable results list with quick buying, red-gray tint on unusable items (list + native grid), EN/FR localization.
