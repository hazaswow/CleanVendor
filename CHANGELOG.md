# Changelog

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
