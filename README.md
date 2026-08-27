[简体中文](README.zhCN.md)

# Extra Items Bar

A standalone extraction of the **"Extra Items Bar"** module from
[ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools).

Adds up to 5 configurable bars that show quest items and usable equipment, so
you never miss a quest objective or trinket in combat. **No ElvUI required.**

## Features

- Up to 5 fully configurable bars
- Automatic quest-item tracking (auto-sorted by quest distance)
- Equipped usable items (with optional slot filters, e.g. `SLOT:13-14`)
- Convenience items: potions, flasks, runes, vantus runes, crafted food, vendor
  food, mage food, fishing, banners, utilities, openable items, profession
  items, seeds, big dig, delves, holiday reward boxes
- Custom item list and blacklist
- Optional auto-blacklist of "quantum" items
- Drag-and-drop positioning (`/eib unlock`) saved per character
- Per-bar layout (anchor, spacing, size, rows), backdrop, mouse-over fade,
  crafting-quality badge, item count, and key-binding display
- Tooltips on hover

## Installation

Copy the `ExtraItemsBar` folder into `World of Warcraft/_retail_/Interface/AddOns/`
(or your flavor's `Interface/AddOns` folder) and restart the game.

Requires WoW 12.1+ (TOC `120100`). `LibSharedMedia-3.0` is optional and only
used to pick extra fonts.

## Usage

| Command          | Action                          |
| ---------------- | ------------------------------- |
| `/eib`          | Open the settings panel         |
| `/eib unlock`   | Toggle drag-and-drop mode       |
| `/eib reset`    | Reset all bar positions         |
| `/eib help`     | Show this help                  |

Settings are available under **Options → AddOns → Extra Items Bar**.

### Button groups

Each bar shows a comma-separated list of group codes in its `Button Groups`
field, e.g. the default bar 1:

```
QUEST,BANNER,EQUIP,PROFMN,HOLIDAY,OPENABLE,DELVE
```

Available codes (the edit box tooltip lists them all):

- `QUEST` — quest items (auto-sorted by distance)
- `EQUIP` — equipped usable items
- `SLOT:1-19` / `SLOT:13` — equipped items filtered by slot
- `CUSTOM` — your custom item list
- `POTION`, `POTIONGN`, `POTIONLEG`, `POTIONSL`, `POTIONDF`, `POTIONTWW`, `POTIONMN`
- `FLASK`, `FLASKLEG`, `FLASKSL`, `FLASKDF`, `FLASKTWW`, `FLASKMN`
- `RUNE`, `RUNETWW`, `RUNEMN`
- `VANTUS`, `VANTUSTWW`, `VANTUSMN`
- `FOOD`, `FOODTWW`, `FOODMN`, `FOODVENDOR`, `MAGEFOOD`
- `FISHING`, `FISHINGTWW`, `FISHINGMN`
- `BANNER`, `UTILITY`, `OPENABLE`
- `PROF`, `PROFTWW`, `PROFMN`
- `SEEDS`, `BIGDIG`, `DELVE`, `HOLIDAY`

## Default settings

Each of the 5 bars starts from this template (overrides noted per bar):

| Setting              | Default                                |
| -------------------- | -------------------------------------- |
| Enable               | true (bars 4 & 5 default **false**)    |
| Mouse-over fade      | false                                  |
| Global fade          | false                                  |
| Visibility           | `[petbattle]hide;show`                 |
| Fade time            | 0.3                                    |
| Alpha min / max      | 0 / 1                                  |
| Number of buttons    | 12                                     |
| Buttons per row      | 12                                     |
| Button size          | 30 × 30                                |
| Anchor point         | TOPLEFT                                |
| Spacing / Snap       | 2 / 2                                  |
| Backdrop             | true                                   |
| Tooltip              | true                                   |
| Quality-tier badge   | size 16, offset (0, 0)                 |
| Count / Keybind font | DefaultFont, size 12, OUTLINE, white  |
| Addon-wide           | noQuantumItems = false, barStyle = auto |

Button-group (`include`) per bar:

- **Bar 1** (enabled): `QUEST,BANNER,EQUIP,PROFMN,HOLIDAY,OPENABLE,DELVE`
- **Bar 2** (enabled): `POTIONMN,FLASKMN,VANTUSMN,UTILITY`
- **Bar 3** (enabled): `MAGEFOOD,FOODVENDOR,FOODMN,RUNEMN,CUSTOM`
- **Bar 4** (disabled): `CUSTOM`
- **Bar 5** (disabled): `CUSTOM`

(A built-in blacklist excludes a few known-problematic items; see `DB.lua`.)

## Attribution & License

This addon is a standalone extraction of the **Extra Items Bar** module from
ElvUI_WindTools by **fang2hou**. The feature was originally ported into
ElvUI_WindTools from **EUI** (author: **cadcamzy**).

The upstream project is distributed under a restricted-source license: within
the ElvUI/NDui ecosystems the code is GPLv3-licensed, while copying, reuse,
porting, or redistribution outside those ecosystems requires a separate written
license from the author. This addon does **not** depend on ElvUI and is used
and modified here with the author's permission.

Please keep this notice, the `NOTICE.txt` file, and the per-file attribution
comments intact if you redistribute or further modify this addon.

## Changes vs. the original module

- Removed the ElvUI/WindTools framework dependency entirely (no Ace libraries).
- ElvUI profile DB → `EIB_DB` SavedVariables.
- ElvUI mover → self-implemented drag & unlock system (`Move.lua`).
- ElvUI options tree → Blizzard "Interface Options" panel.
- ElvUI ActionBars global fade & WindTools shadow skins → removed.
- `AceEvent-3.0` → lightweight native event dispatcher (`Event.lua`).
- WindTools `Async` → trimmed copy embedded in the addon (`Async.lua`).