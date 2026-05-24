-- Locales/zhCN.lua
-- Simplified Chinese (zhCN) localization for MogCompanions.
-- Contributed by XingDVD.
if (GetLocale() == "zhCN") then
local L = MogCompanionsLocales;

-- Core

-- Character Title
L["Character Title Tooltip Header"] = "角色头衔";
L["Character Title Tooltip Set"] = "当你穿着此套装并使用坐骑时，你的头衔将变更为所选头衔。";
L["Character Title Tooltip Unset"] = "此套装不会改变你的头衔。选择一个头衔后，当你穿着此套装并使用坐骑时，头衔将自动变更。";
L["Default Title"] = "[不更改头衔]";

-- Slots
L["Item Slot Flying Mount Title"] = "飞行坐骑";
L["Item Slot Ground Mount Title"] = "地面坐骑";
L["Item Slot Hearthstone Title"] = "炉石";
L["Item Slot Pet Title"] = "宠物";
L["Item Slot Flying Mount Clear Tooltip"] = "清除飞行坐骑";
L["Item Slot Ground Mount Clear Tooltip"] = "清除地面坐骑";
L["Item Slot Hearthstone Clear Tooltip"] = "清除炉石";
L["Item Slot Pet Clear Tooltip"] = "清除宠物";
L["Selected Count Format"] = "(已选择 %d 个)";
L["Random From Selected Mounts"] = "在 %d 个坐骑中随机召唤";
L["More Selected Mounts"] = "+%d 个";
L["Random From Selected Hearthstones"] = "在 %d 个炉石中随机使用";
L["More Selected Hearthstones"] = "+%d 个";
L["Random From Selected Pets"] = "在 %d 个宠物中随机召唤";
L["More Selected Pets"] = "+%d 个";
L["No Pet"] = "不召唤宠物";
L["Random Pet"] = "随机宠物";
L["Random Favorite Pet"] = "随机收藏宠物";
L["No Pet Tooltip"] = "当此套装激活时，解散你当前召唤的宠物。";
L["Random Pet Tooltip"] = "当此套装激活时，随机召唤一个你拥有的可召唤宠物。";
L["Random Favorite Pet Tooltip"] = "当此套装激活时，随机召唤一个你拥有的收藏宠物。";
L["Random Favorite Mount"] = "随机收藏坐骑";
L["Random Favorite Flying Mount Tooltip"] = "为此套装随机召唤一个收藏的飞行坐骑。";
L["Random Favorite Ground Mount Tooltip"] = "为此套装随机召唤一个收藏的地面坐骑。";
L["Random Passenger Mount"] = "随机乘客坐骑";
L["Random Passenger Flying Mount Tooltip"] = "为此套装随机召唤一个可搭载乘客的飞行坐骑。如果没有可用的，则退回到可搭载乘客的地面坐骑。";
L["Random Passenger Ground Mount Tooltip"] = "为此套装随机召唤一个可搭载乘客的地面坐骑。";
L["Pet Macro Tooltip Random"] = "召唤随机宠物";
L["Pet Macro Tooltip Favorite"] = "召唤随机收藏宠物";
L["Pet Macro Tooltip None"] = "解散宠物";

-- Tab
L["Companions Tab Title"] = "幻化伙伴";
L["Mount Tab Title"] = "坐骑";
L["Mount Tab Flying Section Title"] = "飞行";
L["Mount Tab Ground Section Title"] = "地面";
L["Hearthstone Tab Title"] = "炉石";
L["Pets Tab Title"] = "宠物";
L["Pets Tab Section Title"] = "宠物";

-- Settings buttons
L["Binding Mount/Dismount"] = "召唤/解散坐骑";
L["Open Settings"] = "开启选项";
L["Open Keybinds"] = "开启按键绑定";
L["Create Mount Macro"] = "创建坐骑宏";
L["Create Pet Macro"] = "创建宠物宏";
L["Create Hearthstone Macro"] = "创建炉石宏";
L["Setup Reminder"] = "设置一个 Mog Companions 的按键绑定和/或宏";
L["Drop Macro Tooltip"] = "将此坐骑宏拖拽到|n你的动作条上";
L["Drop Pet Macro Tooltip"] = "将此宠物宏拖拽到|n你的动作条上";
L["Drop Hearthstone Macro Tooltip"] = "将此炉石宏拖拽到|n你的动作条上";
L["Show Flying In Ground Toggle"] = "在地面坐骑列表中显示飞行坐骑";
L["Show Selected"] = "显示已选择";
L["Show All"] = "显示全部";
L["No Items Match Search"] = "没有物品匹配你的搜索";
L["Slash Help Mount Base"] = "使用 Mog Companions 进行召唤或解散坐骑";
L["Slash Help Mount"] = "召唤特定类型的坐骑：飞行、地面、水生、修理、随机、收藏或乘客坐骑";
L["Slash Help Pet Base"] = "根据激活的套装召唤伙伴宠物";
L["Slash Help Pet"] = "直接召唤或解散宠物：随机、收藏或解散";
L["Slash Help Options"] = "开启 Mog Companions 选项面板";
L["No Hearthstone Toys"] = "没有可用的炉石玩具。";
L["Use Hearthstone"] = "使用炉石";
L["Macro Combat Error"] = "你在战斗中时，Mog Companions无法创建宏。";
L["MogMount Conflict Prompt"] = "MogMount 和 Mog Companions 均已启用";
L["MogMount Conflict Body"] = "这些插件不能同时管理 Mog Companions 设置。请选择你想要如何继续。";
L["Use MogMount"] = "使用 MogMount";
L["Use MogCompanions"] = "使用 Mog Companions";
L["Disable MogMount"] = "禁用 MogMount";
L["Disable MogMount Description"] = "继续使用 Mog Companions 并为此角色禁用 MogMount。";
L["Transfer MogMount"] = "转移 MogMount 到 Mog Companions";
L["Transfer MogMount Button"] = "转移设置";
L["Transfer MogMount Description"] = "将你的 MogMount 套装设置转移到 Mog Companions 中，并为此角色禁用 MogMount。";
L["Disable MogCompanions"] = "禁用 Mog Companions";
L["Disable MogCompanions Description"] = "继续使用 MogMount 并为此角色禁用 Mog Companions。";
L["MogMount Disabled"] = "MogMount 已禁用。正在重载界面。";
L["MogCompanions Disabled"] = "Mog Companions 已禁用。正在重载界面。";
L["MogMount Import Complete"] = "MogMount 设置已转移。正在禁用 MogMount 并重载界面。";
L["MogMount Import No Data"] = "未找到可转移的 MogMount 设置。";
L["MogMount Import Failed"] = "MogMount 设置无法转移。";

-- Settings

-- Title
L["Settings Default Section Title"] = "默认";

-- Rows
L["Settings Aquatic Mount"] = "水栖坐骑";
L["Settings Aquatic Mount Tooltip"] = "选择在游泳时按住 Ctrl 键要使用的水栖坐骑。当设置为随机时，每次都会从你的收藏中随机使用一个水栖坐骑。";
L["Settings Aquatic Mount Keybind Reminder"] = "游泳时按住 [KEY] 来召唤此坐骑。（使用“强制地面”修饰键。）";

L["Settings Repair Mount"] = "修理坐骑";
L["Settings Repair Mount Tooltip"] = "选择在按住 Shift 键时要使用的商人或修理坐骑。当设置为随机时，每次都会从你的收藏中随机使用一个商人坐骑。";
L["Settings Repair Mount Keybind Reminder"] = "按住 [KEY] 来召唤此坐骑。";

-- Dropdown options
L["Settings Random Selection Label"] = "随机";
L["Settings No Applicable Mounts"] = "没有适用的坐骑";

-- Mount Macro Modifier Settings
L["Settings Mount Macro Title"] = "坐骑宏";
L["Settings Summon Flying Mount"] = "召唤飞行坐骑";
L["Settings Summon Ground Mount"] = "强制召唤地面坐骑";
L["Settings Summon Repair Mount"] = "召唤修理坐骑";
L["Settings Summon Random Mount"] = "召唤随机坐骑";

-- Hearthstone Macro Modifier Settings
L["Settings Hearthstone Macro Title"] = "炉石宏";
L["Settings Use Selected Hearthstone"] = "使用选定的炉石池";
L["Settings Use Garrison Hearthstone"] = "使用要塞炉石";
L["Settings Use Dalaran Hearthstone"] = "使用达拉然炉石";
L["Settings Teleport Home"] = "传送回家（即将推出）";

-- Pet Macro Modifier Settings
L["Settings Pet Macro Title"] = "宠物宏";
L["Settings Summon Selected Pet"] = "召唤选定的宠物池";
L["Settings Summon Random Pet"] = "召唤随机宠物";
L["Settings Summon Random Favorite Pet"] = "召唤随机喜爱宠物";
L["Settings Dismiss Pet"] = "解散宠物";
L["Settings Pet Auto Summon Title"] = "宠物自动召唤";
L["Settings Summon Pet On Outfit Change"] = "更换套装时召唤宠物";
L["Settings Summon Pet On Outfit Change Tooltip"] = "当你的激活套装改变时，从该套装选定的宠物池中召唤宠物。\n\n如果套装未选定宠物，则无任何操作。";
L["Settings Summon Pet On Mount"] = "上坐骑/下坐骑时召唤宠物";
L["Settings Summon Pet On Mount Tooltip"] = "召唤坐骑或解散坐骑后，从激活套装选定的宠物池中召唤宠物。\n\n如果套装未选定宠物，则无任何操作。";
L["Settings Summon Pet On Login"] = "进入区域时召唤宠物";
L["Settings Summon Pet On Login Tooltip"] = "当你登录、重载界面、更换区域、复活或乘坐飞行路线时，从激活套装选定的宠物池中召唤宠物。\n\n当启用解散设置时，进入对应副本类型将解散你的宠物。离开时将恢复。\n\n如果套装未选定宠物，则无任何操作。";
L["Settings Dismiss Pet In PvE"] = "在PvE副本中解散宠物";
L["Settings Dismiss Pet In PvE Tooltip"] = "当你进入地下城或团队副本时，解散你的激活宠物。\n\n同时防止在你处于PvE副本内时，自动召唤功能放置宠物。";
L["Settings Dismiss Pet In PvP"] = "在PvP副本中解散宠物";
L["Settings Dismiss Pet In PvP Tooltip"] = "当你进入战场或竞技场时，解散你的激活宠物。\n\n同时防止在你处于PvP副本内时，自动召唤功能放置宠物。";

-- Modifier Key Labels
L["Settings CTRL"] = "CTRL";
L["Settings SHIFT"] = "SHIFT";
L["Settings ALT"] = "ALT";
L["Settings CTRL Key"] = "CTRL 键";
L["Settings SHIFT Key"] = "SHIFT 键";
L["Settings ALT Key"] = "ALT 键";
L["Settings Click"] = "点击";

-- Random selection section
L["Settings Random Section Title"] = "随机坐骑选择";
L["Settings Random Ground Allow Flying"] = "允许'飞行坐骑'";
L["Settings Random Ground Allow Flying Tooltip"] = "关闭此功能以限制随机地面坐骑仅使用非飞行坐骑。";
L["Settings Clone Targeted Mount"] = "克隆目标坐骑";
L["Settings Clone Targeted Mount Tooltip"] = "召唤随机坐骑时，若选中一名已骑乘的玩家，则会尝试召唤相同的坐骑（如果你拥有该坐骑）。";

-- Random pet selection section
L["Settings Random Pet Section Title"] = "随机宠物选择";
L["Settings Clone Targeted Pet"] = "克隆目标宠物";
L["Settings Clone Targeted Pet Tooltip"] = "使用宠物宏或按键绑定时，若选中一名玩家的随身宠物，则会尝试召唤相同的宠物（如果你拥有该宠物）。";

-- Macros section
L["Settings Create Mount Macro"] = "创建坐骑宏";
L["Settings Create Mount Macro Tooltip"] = "创建或更新 Mog Companions 坐骑宏，并将其置于鼠标光标上。";
L["Settings Create Hearthstone Macro"] = "创建炉石宏";
L["Settings Create Hearthstone Macro Tooltip"] = "创建或更新 Mog Companions 炉石宏，并将其置于鼠标光标上。";
L["Settings Create Pet Macro"] = "创建宠物宏";
L["Settings Create Pet Macro Tooltip"] = "创建或更新 Mog Companions 宠物宏，并将其置于鼠标光标上。";
L["Settings Dynamic Mount Macro Icon"] = "动态更改坐骑图标";
L["Settings Dynamic Mount Macro Icon Tooltip"] = "启用后，坐骑宏图标会尽可能更新为与当前分配的坐骑相匹配。禁用时，始终使用坐骑占位符图标。";
L["Settings Dynamic Pet Macro Icon"] = "动态更改宠物图标";
L["Settings Dynamic Pet Macro Icon Tooltip"] = "启用后，宠物宏图标会尽可能更新为与当前选择的宠物相匹配。禁用时，始终使用宠物占位符图标。";

end
