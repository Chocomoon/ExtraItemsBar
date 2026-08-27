[English](README.md)

# Extra Items Bar（额外物品条）

独立提取自 [ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools) 的 **「额外物品条」** 模块。

最多提供 5 条可配置的物品条，用于显示任务物品与可用装备，让你在战斗中不再错过任何任务目标或饰品。**无需 ElvUI。**

## 功能特性

- 最多 5 条完全可配置的物品条
- 任务物品自动追踪（按任务距离自动排序）
- 已装备的可用物品（支持按装备栏位筛选，例如 `SLOT:13-14`）
- 便捷物品：药水、合剂、符文、范图斯符文、烹饪食物、商贩食物、法师食物、钓鱼、战旗、实用品、可开启物品、专业物品、种子、大挖掘、深窟、节日奖励箱
- 自定义物品列表与黑名单
- 可选「量子物品」自动黑名单
- 拖拽定位（`/eib unlock`），按角色保存
- 每条物品条独立布局（锚点、间距、尺寸、行数）、背景、鼠标悬停淡出、制造品质角标、物品计数与按键绑定显示
- 悬停显示提示框

## 安装

将 `ExtraItemsBar` 文件夹复制到 `World of Warcraft/_retail_/Interface/AddOns/`（或对应版本的 `Interface/AddOns` 文件夹），然后重启游戏。

需要 WoW 12.1+（TOC `120100`）。`LibSharedMedia-3.0` 为可选依赖，仅用于选择额外字体。

## 使用

| 命令             | 作用                       |
| ---------------- | -------------------------- |
| `/eib`          | 打开设置面板               |
| `/eib unlock`   | 切换拖拽定位模式           |
| `/eib reset`    | 重置所有物品条位置         |
| `/eib help`     | 显示本帮助                 |

设置位于 **选项 → 插件 → Extra Items Bar**。

### 按钮分组

每条物品条在其「按钮分组」(Button Groups) 字段中以逗号分隔的组代码表示，例如默认的第 1 条物品条：

```
QUEST,BANNER,EQUIP,PROFMN,HOLIDAY,OPENABLE,DELVE
```

可用代码（编辑框提示中列出全部）：

- `QUEST` — 任务物品（按距离自动排序）
- `EQUIP` — 已装备的可用物品
- `SLOT:1-19` / `SLOT:13` — 按装备栏位筛选的已装备物品
- `CUSTOM` — 你的自定义物品列表
- `POTION`, `POTIONGN`, `POTIONLEG`, `POTIONSL`, `POTIONDF`, `POTIONTWW`, `POTIONMN`
- `FLASK`, `FLASKLEG`, `FLASKSL`, `FLASKDF`, `FLASKTWW`, `FLASKMN`
- `RUNE`, `RUNETWW`, `RUNEMN`
- `VANTUS`, `VANTUSTWW`, `VANTUSMN`
- `FOOD`, `FOODTWW`, `FOODMN`, `FOODVENDOR`, `MAGEFOOD`
- `FISHING`, `FISHINGTWW`, `FISHINGMN`
- `BANNER`, `UTILITY`, `OPENABLE`
- `PROF`, `PROFTWW`, `PROFMN`
- `SEEDS`, `BIGDIG`, `DELVE`, `HOLIDAY`

## 默认设置

5 条物品条均从此模板起步（各条覆盖项见下方）：

| 设置项             | 默认值                                   |
| ------------------ | ---------------------------------------- |
| 启用               | true（第 4、5 条默认 **false**）         |
| 鼠标悬停淡出       | false                                    |
| 全局淡出           | false                                    |
| 可见性             | `[petbattle]hide;show`                   |
| 淡出时间           | 0.3                                      |
| 透明度 最小/最大   | 0 / 1                                    |
| 按钮数量           | 12                                       |
| 每行按钮数         | 12                                       |
| 按钮尺寸           | 30 × 30                                  |
| 锚点               | TOPLEFT                                  |
| 间距 / 吸附间距    | 2 / 2                                    |
| 背景               | true                                     |
| 提示框             | true                                     |
| 制造品质角标       | 尺寸 16，偏移 (0, 0)                     |
| 计数 / 按键字体    | DefaultFont，尺寸 12，OUTLINE，白色      |
| 插件级             | noQuantumItems = false，barStyle = auto  |

各物品条的按钮分组（`include`）：

- **第 1 条**（启用）：`QUEST,BANNER,EQUIP,PROFMN,HOLIDAY,OPENABLE,DELVE`
- **第 2 条**（启用）：`POTIONMN,FLASKMN,VANTUSMN,UTILITY`
- **第 3 条**（启用）：`MAGEFOOD,FOODVENDOR,FOODMN,RUNEMN,CUSTOM`
- **第 4 条**（禁用）：`CUSTOM`
- **第 5 条**（禁用）：`CUSTOM`

（内置黑名单会排除少数已知有问题的物品，详见 `DB.lua`。）

## 归属与许可

本插件是从 **fang2hou** 的 ElvUI_WindTools 中独立提取的 **「额外物品条」** 模块。该功能最初由 **cadcamzy** 从 **EUI** 移植进 ElvUI_WindTools。

上游项目采用受限源代码许可：在 ElvUI/NDui 生态内代码以 GPLv3 许可，而在这些生态之外进行复制、复用、移植或再分发则需获得作者的单独书面许可。本插件 **不** 依赖 ElvUI，并在获得作者许可的情况下使用与修改。

若你再分发或继续修改本插件，请保留本声明、`NOTICE.txt` 文件以及各文件内的归属注释。

## 与原模块的改动

- 完全移除对 ElvUI/WindTools 框架的依赖（不含 Ace 库）。
- ElvUI 配置库 → `EIB_DB` 保存变量。
- ElvUI 移动器 → 自实现的拖拽与解锁系统（`Move.lua`）。
- ElvUI 选项树 → 暴雪「界面选项」面板。
- ElvUI ActionBars 全局淡出与 WindTools 阴影皮肤 → 已移除。
- `AceEvent-3.0` → 轻量原生事件分发器（`Event.lua`）。
- WindTools `Async` → 内置的精简副本（`Async.lua`）。
