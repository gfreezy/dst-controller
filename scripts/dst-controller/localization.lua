-- Enhanced Controller - Localization
-- 多语言支持模块

local G = require("dst-controller/global")

local Localization = {}

-- 语言字符串表
local STRINGS_TABLE = {
    -- 英文
    en = {
        -- 主界面
        TITLE = "Enhanced Controller Configuration",
        TAB_TASKS = "Button Config",
        TAB_VIRTUAL_CURSOR = "Virtual Cursor",
        TAB_SETTINGS = "Mod Settings",
        BUTTON_APPLY = "Apply",
        BUTTON_CLOSE = "Close",
        BUTTON_CONFIRM = "Confirm",
        BUTTON_CANCEL = "Cancel",
        BUTTON_SAVE = "Save",
        BUTTON_ADD_ACTION = "+ Add Action",
        BUTTON_EDIT = "Edit",
        BUTTON_DELETE = "Delete",
        BUTTON_CONFIG = "Config",

        -- 地图位置面板
        LOCATION_PANEL_TITLE = "Locations",
        LOCATION_TAB_PLAYERS = "Players",
        LOCATION_TAB_FAVORITES = "Favorites",
        LOCATION_QUERY_ALL = "Query All Players",
        LOCATION_QUERY = "Query",
        LOCATION_REFRESH = "Refresh",
        LOCATION_ADD_CURRENT = "Favorite Current Position",
        LOCATION_NAME_PROMPT = "Name This Position",
        LOCATION_RENAME_PROMPT = "Rename Favorite",
        LOCATION_DEFAULT_NAME = "Favorite %d",
        LOCATION_NO_PLAYERS = "No players",
        LOCATION_NO_FAVORITES = "No favorite positions in this world",
        LOCATION_STATUS_NOT_QUERIED = "Not queried",
        LOCATION_STATUS_QUERYING = "Querying...",
        LOCATION_STATUS_LOCATED = "Located",
        LOCATION_STATUS_OTHER_SHARD = "Other shard",
        LOCATION_STATUS_UNAVAILABLE = "No response",

        -- 按钮组合配置
        PRESS_COUNT = "Press:%d  Release:%d",

        -- 设置项标签
        SETTING_ATTACK_ANGLE = "Attack Angle Mode",
        SETTING_INTERACTION_ANGLE = "Interaction Angle Mode",
        SETTING_FORCE_ATTACK = "Force Attack Mode",
        SETTING_AIR_ATTACK = "Allow Air Attack",
        SETTING_VIRTUAL_CURSOR = "Virtual Cursor",
        SETTING_CURSOR_SPEED = "Cursor Speed",
        SETTING_SHOW_CURSOR = "Show Cursor Widget",
        SETTING_CURSOR_MAGNETISM = "Cursor Snap Enable",
        SETTING_MAGNETISM_RANGE = "Snap Range",
        SETTING_TARGET_PRIORITY = "Snap Priority",
        SETTING_ACTIONQUEUE_INTEGRATION = "ActionQueue Controller",
        SETTING_DEBUG_LOGGING = "Debug Logging",
        SETTING_CRAFT_SEARCH_RADIUS = "Auto Build Radius",
        SETTING_CRAFT_SEARCH_MODE = "Container Search",
        SETTING_CRAFT_MAX_CONTAINERS = "Container Limit",

        -- 设置项选项
        OPT_FORWARD_ONLY = "Forward Only",
        OPT_ALL_AROUND = "360° All Around",
        OPT_HOSTILE_ONLY = "Hostile Only (LB+X Force)",
        OPT_FORCE_ATTACK = "All Attackable",
        OPT_DISABLED = "Disabled",
        OPT_ENABLED = "Enabled",
        OPT_SPEED_SLOW = "Very Slow (0.5x)",
        OPT_SPEED_SLOWER = "Slow (0.75x)",
        OPT_SPEED_NORMAL = "Normal (1.0x)",
        OPT_SPEED_FAST = "Fast (1.5x)",
        OPT_SPEED_FASTER = "Very Fast (2.0x)",
        OPT_HIDE = "Hide",
        OPT_SHOW = "Show",
        OPT_OFF = "Off",
        OPT_ON = "On",
        OPT_RANGE_SHORT = "Short",
        OPT_RANGE_MEDIUM = "Medium",
        OPT_RANGE_LONG = "Long",
        OPT_CURSOR_PRIORITY = "Cursor Priority",
        OPT_PLAYER_PRIORITY = "Player Priority",
        OPT_CRAFT_SMART = "Smart (stop when ready)",
        OPT_CRAFT_THOROUGH = "Thorough (check all)",
        OPT_UNLIMITED = "Unlimited",

        -- 动作列表
        ACTION_NONE = "【No Action】",
        ACTION_ATTACK = "Attack",
        ACTION_EXAMINE = "Examine",
        ACTION_INSPECT_SELF = "Inspect Self",
        ACTION_USE_ACTIVE_ITEM_ON_SELF = "Use Active Item on Self",
        ACTION_USE_ACTIVE_ITEM_ON_SCENE = "Use Active Item on Scene",
        ACTION_SAVE_HAND_ITEM = "Save Hand Item",
        ACTION_RESTORE_HAND_ITEM = "Restore Hand Item",
        ACTION_CYCLE_HEAD = "Cycle Head Slot",
        ACTION_CYCLE_HAND = "Cycle Hand Slot",
        ACTION_CYCLE_BODY = "Cycle Body Slot",
        ACTION_ENABLE_VIRTUAL_CURSOR = "Enable Virtual Cursor",
        ACTION_DISABLE_VIRTUAL_CURSOR = "Disable Virtual Cursor",
        ACTION_DELAY = "Delay [Needs Param]",
        ACTION_EQUIP_ITEM = "Equip Item [Needs Param]",
        ACTION_UNEQUIP_ITEM = "Unequip Item [Needs Param]",
        ACTION_USE_EQUIP = "Use Equipped Item [Needs Param]",
        ACTION_USE_ITEM_ON_SELF = "Use Item on Self [Needs Param]",
        ACTION_USE_ITEM_ON_SCENE = "Use Item on Scene [Needs Param]",
        ACTION_CRAFT_ITEM = "Craft Item [Needs Param]",
        ACTION_TOGGLE_COOKING_MENU = "Open Cooking List",
        ACTION_TRIGGER_KEY = "Trigger Key [Needs Param]",
        AUTO_CRAFT = "Auto Build",
        SEARCH_AND_BUILD = "Search & Build",
        SEARCH_AND_COOK = "Search & Cook",
        COOKING_MENU_TITLE = "Cooking List",
        COOKING_MENU_HINT = "Right stick: select   A: cook   B: close   Left stick: move",
        COOKING_MENU_STATS = "Health %s   Hunger %s   Sanity %s",
        COOKING_MENU_EMPTY = "No cookable recipes",
        COOKING_MENU_PAGE = "%d / %d",

        -- 动作详情界面
        DETAIL_TITLE_SUFFIX = " - Action Config",
        EMPTY_ACTION_LIST = "No actions\nClick [+ Add Action] button below",
        TAB_ON_PRESS = "On Press",
        TAB_ON_RELEASE = "On Release",

        -- 动作编辑对话框
        EDITOR_TITLE = "Edit Action",
        LABEL_ACTION_TYPE = "Action Type:",
        LABEL_PARAM = "Parameter:",
        LABEL_CUSTOM_PARAM = "Custom Parameter:",
        HINT_CUSTOM_PARAM = "Hint: Select from dropdown or edit in config file manually",
        LABEL_RECIPE_SEARCH = "Recipe Search:",
        LABEL_RECIPE_RESULT = "Recipe:",
        RECIPE_SEARCH_RESULTS = "%d recipes; use the arrows below to choose",
        SEARCH_RESULTS_LIMITED = "Showing the first %d of %d matches; refine the search to narrow it",
        RECIPE_SEARCH_EMPTY = "No matching recipe; try another keyword",
        RECIPE_UNAVAILABLE = "%s [Currently unavailable]",
        LABEL_ITEM_SEARCH = "Item Search:",
        LABEL_ITEM_RESULT = "Item:",
        ITEM_SEARCH_RESULTS = "%d items; use the arrows below to choose",
        ITEM_SEARCH_EMPTY = "No matching item; try another keyword",
        ITEM_UNAVAILABLE = "%s [Currently unavailable]",
        PARAM_REQUIRED = "Select or enter a valid parameter before saving",
        AUTO_CRAFT_STARTED = "Auto Build started: %s",
        AUTO_CRAFT_COMPLETE = "Auto Build complete",
        AUTO_CRAFT_INTERRUPTED = "Auto Build stopped: %s",
        AUTO_CRAFT_UNKNOWN_REASON = "unknown reason",
        AUTO_CRAFT_STAGED_ITEM_MISSING = "Temporarily staged item no longer exists: %s",
        AUTO_CRAFT_REASON_CANCELLED = "cancelled",
        AUTO_CRAFT_REASON_REPLACED = "a new Auto Build was started",
        AUTO_CRAFT_REASON_USER_ACTION = "player took control",
        AUTO_CRAFT_REASON_OPERATION_TIMEOUT = "operation timed out",
        AUTO_CRAFT_REASON_BUILD_NOT_SYNCED = "build result did not synchronize",
        AUTO_CRAFT_REASON_BUILD_TIMEOUT = "build timed out",
        AUTO_CRAFT_REASON_CONTAINER_UNAVAILABLE = "container is unavailable",
        AUTO_CRAFT_REASON_CONTAINER_BUSY = "could not open container",
        AUTO_CRAFT_REASON_CONTAINER_OPEN_FAILED = "opening container failed",
        AUTO_CRAFT_REASON_INSUFFICIENT = "insufficient materials or technology (%s)",
        AUTO_CRAFT_REASON_NO_RESTORE_SPACE = "no room to restore staged items",
        AUTO_CRAFT_REASON_NO_SAFE_SLOT = "no item can be staged safely",
        AUTO_CRAFT_REASON_STAGE_FAILED = "could not free an inventory slot",
        AUTO_CRAFT_REASON_CONTAINER_TAKE_FAILED = "taking material from container failed",
        AUTO_CRAFT_REASON_CONTAINER_TAKE_TIMEOUT = "taking material from container timed out",
        AUTO_CRAFT_REASON_PICKUP_FAILED = "picking up material failed",
        AUTO_CRAFT_REASON_PICKUP_TIMEOUT = "picking up material timed out",
        AUTO_CRAFT_REASON_CACHE_STALE = "container cache changed; missing %s",
        AUTO_CRAFT_REASON_SOURCE_CHANGED = "verified materials changed; missing %s",
        AUTO_CRAFT_REASON_CONTAINER_CLOSE_FAILED = "closing container failed",
        AUTO_CRAFT_REASON_PRECHECK_FAILED = "ingredient check failed before crafting %s",
        AUTO_CRAFT_REASON_PRODUCT_NOT_STORED = "crafted product did not enter inventory: %s",
        AUTO_CRAFT_REASON_UNEQUIP_PRODUCT_FAILED = "could not recover an auto-equipped intermediate",
        AUTO_CRAFT_REASON_FINAL_PRECHECK_FAILED = "final ingredient check failed",
        AUTO_CRAFT_REASON_BUFFER_FAILED = "structure buffering failed",
        AUTO_CRAFT_REASON_MANUFACTURE_FAILED = "station did not confirm the result",
        AUTO_CRAFT_REASON_RETURN_FAILED = "returning excess external materials failed",
        AUTO_CRAFT_REASON_RESTORE_FAILED = "restoring staged item failed",
        AUTO_CRAFT_REASON_PLAN_INCOMPLETE = "build plan is incomplete",
        AUTO_CRAFT_REASON_UNKNOWN_STEP = "unknown build-plan step",
        AUTO_CRAFT_REASON_GAME_STATE = "game state changed",
        AUTO_COOK_STARTED = "Search & Cook started: %s",
        AUTO_COOK_COMPLETE = "Cooking started: %s",
        AUTO_COOK_INTERRUPTED = "Search & Cook stopped: %s",
        AUTO_COOK_UNKNOWN_REASON = "unknown reason",
        AUTO_COOK_REASON_CANCELLED = "cancelled",
        AUTO_COOK_REASON_REPLACED = "a new Search & Cook was started",
        AUTO_COOK_REASON_USER_ACTION = "player took control",
        AUTO_COOK_REASON_OPERATION_TIMEOUT = "operation timed out",
        AUTO_COOK_REASON_CONTAINER_BUSY = "could not interact with a container",
        AUTO_COOK_REASON_CONTAINER_OPEN_FAILED = "opening the ingredient container failed",
        AUTO_COOK_REASON_NO_DISCOVERED_RECIPE = "no discovered ingredient combination is available",
        AUTO_COOK_REASON_NO_COOKER = "no nearby empty compatible cooker was found",
        AUTO_COOK_REASON_INSUFFICIENT = "nearby ingredients cannot make the selected dish",
        AUTO_COOK_REASON_COOKER_UNAVAILABLE = "the selected cooker is no longer available",
        AUTO_COOK_REASON_COOKER_OPEN_FAILED = "opening the cooker failed",
        AUTO_COOK_REASON_COOKER_CHANGED = "the cooker's contents changed",
        AUTO_COOK_REASON_TRANSFER_FAILED = "moving an ingredient into the cooker failed",
        AUTO_COOK_REASON_RECIPE_MISMATCH = "the filled ingredients no longer make the selected dish",
        AUTO_COOK_REASON_START_FAILED = "the cooker did not start",
        AUTO_COOK_REASON_GAME_STATE = "game state changed",

        -- 参数预设
        PRESET_CUSTOM = "【Custom Input】",
        PRESET_LIGHTER = "Lighter (lighter)",
        PRESET_TORCH = "Torch (torch)",
        PRESET_LANTERN = "Lantern (lantern)",
        PRESET_PICKAXE = "Pickaxe (pickaxe)",
        PRESET_AXE = "Axe (axe)",
        PRESET_SHOVEL = "Shovel (shovel)",
        PRESET_HAMMER = "Hammer (hammer)",
        PRESET_SPEAR = "Spear (spear)",
        PRESET_LOG = "Log (log)",
        PRESET_CUTGRASS = "Grass (cutgrass)",
        PRESET_TWIGS = "Twigs (twigs)",
        PRESET_ROCKS = "Rocks (rocks)",
        PRESET_FLINT = "Flint (flint)",
        PRESET_GOLDNUGGET = "Gold Nugget (goldnugget)",

        -- 键盘按键
        KEY_SPACE = "Space",
        KEY_ENTER = "Enter",
        KEY_ESCAPE = "Escape",
        KEY_TAB = "Tab",
        KEY_BACKSPACE = "Backspace",

        -- 装备槽位
        SLOT_HAND = "Hand",
        SLOT_HEAD = "Head",
        SLOT_BODY = "Body",
    },

    -- 中文（简体）
    zh = {
        -- 主界面
        TITLE = "增强手柄配置",
        TAB_TASKS = "按键配置",
        TAB_VIRTUAL_CURSOR = "虚拟光标",
        TAB_SETTINGS = "Mod设置",
        BUTTON_APPLY = "应用",
        BUTTON_CLOSE = "关闭",
        BUTTON_CONFIRM = "确定",
        BUTTON_CANCEL = "取消",
        BUTTON_SAVE = "保存",
        BUTTON_ADD_ACTION = "+ 添加动作",
        BUTTON_EDIT = "编辑",
        BUTTON_DELETE = "删除",
        BUTTON_CONFIG = "配置",

        -- 地图位置面板
        LOCATION_PANEL_TITLE = "位置",
        LOCATION_TAB_PLAYERS = "玩家位置",
        LOCATION_TAB_FAVORITES = "收藏位置",
        LOCATION_QUERY_ALL = "查询全部玩家",
        LOCATION_QUERY = "查询",
        LOCATION_REFRESH = "刷新",
        LOCATION_ADD_CURRENT = "收藏当前位置",
        LOCATION_NAME_PROMPT = "为当前位置命名",
        LOCATION_RENAME_PROMPT = "重命名收藏位置",
        LOCATION_DEFAULT_NAME = "收藏点 %d",
        LOCATION_NO_PLAYERS = "没有可查询的玩家",
        LOCATION_NO_FAVORITES = "当前世界还没有收藏位置",
        LOCATION_STATUS_NOT_QUERIED = "未查询",
        LOCATION_STATUS_QUERYING = "查询中...",
        LOCATION_STATUS_LOCATED = "已获取",
        LOCATION_STATUS_OTHER_SHARD = "其他分片",
        LOCATION_STATUS_UNAVAILABLE = "无响应",

        -- 按钮组合配置
        PRESS_COUNT = "按下:%d  松开:%d",

        -- 设置项标签
        SETTING_ATTACK_ANGLE = "攻击角度模式",
        SETTING_INTERACTION_ANGLE = "交互角度模式",
        SETTING_FORCE_ATTACK = "强制攻击模式",
        SETTING_AIR_ATTACK = "允许空气攻击",
        SETTING_VIRTUAL_CURSOR = "虚拟光标",
        SETTING_CURSOR_SPEED = "光标速度",
        SETTING_SHOW_CURSOR = "显示光标图标",
        SETTING_CURSOR_MAGNETISM = "光标磁吸启用",
        SETTING_MAGNETISM_RANGE = "磁吸范围",
        SETTING_TARGET_PRIORITY = "磁吸优先级",
        SETTING_ACTIONQUEUE_INTEGRATION = "ActionQueue 手柄适配",
        SETTING_DEBUG_LOGGING = "调试日志",
        SETTING_CRAFT_SEARCH_RADIUS = "自动建造范围",
        SETTING_CRAFT_SEARCH_MODE = "容器搜索模式",
        SETTING_CRAFT_MAX_CONTAINERS = "最多检查容器",

        -- 设置项选项
        OPT_FORWARD_ONLY = "仅前方",
        OPT_ALL_AROUND = "360度全方位",
        OPT_HOSTILE_ONLY = "仅敌对 (LB+X强攻)",
        OPT_FORCE_ATTACK = "全部可攻击",
        OPT_DISABLED = "禁用",
        OPT_ENABLED = "启用",
        OPT_SPEED_SLOW = "很慢 (0.5x)",
        OPT_SPEED_SLOWER = "慢 (0.75x)",
        OPT_SPEED_NORMAL = "正常 (1.0x)",
        OPT_SPEED_FAST = "快 (1.5x)",
        OPT_SPEED_FASTER = "很快 (2.0x)",
        OPT_HIDE = "隐藏",
        OPT_SHOW = "显示",
        OPT_OFF = "关闭",
        OPT_ON = "开启",
        OPT_RANGE_SHORT = "近距离",
        OPT_RANGE_MEDIUM = "中距离",
        OPT_RANGE_LONG = "远距离",
        OPT_CURSOR_PRIORITY = "光标优先",
        OPT_PLAYER_PRIORITY = "玩家优先",
        OPT_CRAFT_SMART = "智能（材料足够即停止）",
        OPT_CRAFT_THOROUGH = "完整（检查全部容器）",
        OPT_UNLIMITED = "不限制",

        -- 动作列表
        ACTION_NONE = "【无动作】",
        ACTION_ATTACK = "攻击",
        ACTION_EXAMINE = "检查",
        ACTION_INSPECT_SELF = "检查自己",
        ACTION_USE_ACTIVE_ITEM_ON_SELF = "对自己使用当前物品",
        ACTION_USE_ACTIVE_ITEM_ON_SCENE = "对场景使用当前物品",
        ACTION_SAVE_HAND_ITEM = "保存手持物品",
        ACTION_RESTORE_HAND_ITEM = "恢复手持物品",
        ACTION_CYCLE_HEAD = "切换头部装备",
        ACTION_CYCLE_HAND = "切换手部装备",
        ACTION_CYCLE_BODY = "切换身体装备",
        ACTION_ENABLE_VIRTUAL_CURSOR = "启用虚拟光标",
        ACTION_DISABLE_VIRTUAL_CURSOR = "禁用虚拟光标",
        ACTION_DELAY = "延迟 [需要参数]",
        ACTION_EQUIP_ITEM = "装备物品 [需要参数]",
        ACTION_UNEQUIP_ITEM = "卸下装备 [需要参数]",
        ACTION_USE_EQUIP = "使用已装备物品 [需要参数]",
        ACTION_USE_ITEM_ON_SELF = "对自己使用物品 [需要参数]",
        ACTION_USE_ITEM_ON_SCENE = "对场景使用物品 [需要参数]",
        ACTION_CRAFT_ITEM = "制作物品 [需要参数]",
        ACTION_TOGGLE_COOKING_MENU = "打开烹饪列表",
        ACTION_TRIGGER_KEY = "触发按键 [需要参数]",
        AUTO_CRAFT = "自动建造",
        SEARCH_AND_BUILD = "搜索并建造",
        SEARCH_AND_COOK = "搜索并烹饪",
        COOKING_MENU_TITLE = "烹饪列表",
        COOKING_MENU_HINT = "右摇杆选择  A 烹饪  B 关闭  左摇杆移动",
        COOKING_MENU_STATS = "生命 %s   饥饿 %s   精神 %s",
        COOKING_MENU_EMPTY = "没有可烹饪料理",
        COOKING_MENU_PAGE = "%d / %d",

        -- 动作详情界面
        DETAIL_TITLE_SUFFIX = " - 动作配置",
        EMPTY_ACTION_LIST = "暂无动作\n点击下方 [+ 添加动作] 按钮",
        TAB_ON_PRESS = "按下动作",
        TAB_ON_RELEASE = "松开动作",

        -- 动作编辑对话框
        EDITOR_TITLE = "编辑动作",
        LABEL_ACTION_TYPE = "动作类型:",
        LABEL_PARAM = "参数:",
        LABEL_CUSTOM_PARAM = "自定义参数:",
        HINT_CUSTOM_PARAM = "提示：请在参数下拉中选择或在配置文件中手动编辑",
        LABEL_RECIPE_SEARCH = "搜索配方:",
        LABEL_RECIPE_RESULT = "配方:",
        RECIPE_SEARCH_RESULTS = "找到 %d 个配方，请用下方箭头选择",
        SEARCH_RESULTS_LIMITED = "当前显示前 %d 个，共找到 %d 个结果，请继续输入关键词缩小范围",
        RECIPE_SEARCH_EMPTY = "没有匹配的配方，请更换关键词",
        RECIPE_UNAVAILABLE = "%s [当前不可用]",
        LABEL_ITEM_SEARCH = "搜索物品:",
        LABEL_ITEM_RESULT = "物品:",
        ITEM_SEARCH_RESULTS = "找到 %d 个物品，请用下方箭头选择",
        ITEM_SEARCH_EMPTY = "没有匹配的物品，请更换关键词",
        ITEM_UNAVAILABLE = "%s [当前不可用]",
        PARAM_REQUIRED = "保存前请选择或输入有效参数",
        AUTO_CRAFT_STARTED = "开始自动搜索建造：%s",
        AUTO_CRAFT_COMPLETE = "自动建造完成",
        AUTO_CRAFT_INTERRUPTED = "自动建造已中断：%s",
        AUTO_CRAFT_UNKNOWN_REASON = "未知原因",
        AUTO_CRAFT_STAGED_ITEM_MISSING = "临时放下的物品已不存在：%s",
        AUTO_CRAFT_REASON_CANCELLED = "任务已取消",
        AUTO_CRAFT_REASON_REPLACED = "启动了新的自动建造",
        AUTO_CRAFT_REASON_USER_ACTION = "用户接管",
        AUTO_CRAFT_REASON_OPERATION_TIMEOUT = "操作超时",
        AUTO_CRAFT_REASON_BUILD_NOT_SYNCED = "制作结果未同步",
        AUTO_CRAFT_REASON_BUILD_TIMEOUT = "制作超时",
        AUTO_CRAFT_REASON_CONTAINER_UNAVAILABLE = "容器不可用",
        AUTO_CRAFT_REASON_CONTAINER_BUSY = "无法打开容器",
        AUTO_CRAFT_REASON_CONTAINER_OPEN_FAILED = "打开容器失败",
        AUTO_CRAFT_REASON_INSUFFICIENT = "材料或科技不足（%s）",
        AUTO_CRAFT_REASON_NO_RESTORE_SPACE = "完成后没有空间恢复临时物品",
        AUTO_CRAFT_REASON_NO_SAFE_SLOT = "背包没有可安全腾出的格子",
        AUTO_CRAFT_REASON_STAGE_FAILED = "临时腾格失败",
        AUTO_CRAFT_REASON_CONTAINER_TAKE_FAILED = "从容器取材失败",
        AUTO_CRAFT_REASON_CONTAINER_TAKE_TIMEOUT = "从容器取材超时",
        AUTO_CRAFT_REASON_PICKUP_FAILED = "拾取材料失败",
        AUTO_CRAFT_REASON_PICKUP_TIMEOUT = "拾取材料超时",
        AUTO_CRAFT_REASON_CACHE_STALE = "容器缓存已失效，缺少 %s",
        AUTO_CRAFT_REASON_SOURCE_CHANGED = "已验证材料发生变化，缺少 %s",
        AUTO_CRAFT_REASON_CONTAINER_CLOSE_FAILED = "关闭容器失败",
        AUTO_CRAFT_REASON_PRECHECK_FAILED = "合成前材料校验失败：%s",
        AUTO_CRAFT_REASON_PRODUCT_NOT_STORED = "制作结果未进入背包：%s",
        AUTO_CRAFT_REASON_UNEQUIP_PRODUCT_FAILED = "无法收回自动装备的次级材料",
        AUTO_CRAFT_REASON_FINAL_PRECHECK_FAILED = "最终建造前材料校验失败",
        AUTO_CRAFT_REASON_BUFFER_FAILED = "建筑缓冲失败",
        AUTO_CRAFT_REASON_MANUFACTURE_FAILED = "制作站未确认制造结果",
        AUTO_CRAFT_REASON_RETURN_FAILED = "归还外部材料失败",
        AUTO_CRAFT_REASON_RESTORE_FAILED = "恢复临时物品失败",
        AUTO_CRAFT_REASON_PLAN_INCOMPLETE = "建造计划不完整",
        AUTO_CRAFT_REASON_UNKNOWN_STEP = "未知建造步骤",
        AUTO_CRAFT_REASON_GAME_STATE = "游戏状态变化",
        AUTO_COOK_STARTED = "开始搜索烹饪：%s",
        AUTO_COOK_COMPLETE = "已开始烹饪：%s",
        AUTO_COOK_INTERRUPTED = "搜索烹饪已中断：%s",
        AUTO_COOK_UNKNOWN_REASON = "未知原因",
        AUTO_COOK_REASON_CANCELLED = "任务已取消",
        AUTO_COOK_REASON_REPLACED = "启动了新的搜索烹饪",
        AUTO_COOK_REASON_USER_ACTION = "用户接管",
        AUTO_COOK_REASON_OPERATION_TIMEOUT = "操作超时",
        AUTO_COOK_REASON_CONTAINER_BUSY = "当前无法操作容器",
        AUTO_COOK_REASON_CONTAINER_OPEN_FAILED = "打开材料容器失败",
        AUTO_COOK_REASON_NO_DISCOVERED_RECIPE = "没有已发现的可用食材组合",
        AUTO_COOK_REASON_NO_COOKER = "附近没有空闲的兼容锅具",
        AUTO_COOK_REASON_INSUFFICIENT = "附近材料无法制作所选料理",
        AUTO_COOK_REASON_COOKER_UNAVAILABLE = "选择的锅具已不可用",
        AUTO_COOK_REASON_COOKER_OPEN_FAILED = "打开锅具失败",
        AUTO_COOK_REASON_COOKER_CHANGED = "锅具内容已发生变化",
        AUTO_COOK_REASON_TRANSFER_FAILED = "向锅具放入材料失败",
        AUTO_COOK_REASON_RECIPE_MISMATCH = "放入的材料已无法制作所选料理",
        AUTO_COOK_REASON_START_FAILED = "锅具未能开始烹饪",
        AUTO_COOK_REASON_GAME_STATE = "游戏状态变化",

        -- 参数预设
        PRESET_CUSTOM = "【自定义输入】",
        PRESET_LIGHTER = "打火机 (lighter)",
        PRESET_TORCH = "火把 (torch)",
        PRESET_LANTERN = "提灯 (lantern)",
        PRESET_PICKAXE = "镐子 (pickaxe)",
        PRESET_AXE = "斧头 (axe)",
        PRESET_SHOVEL = "铲子 (shovel)",
        PRESET_HAMMER = "锤子 (hammer)",
        PRESET_SPEAR = "长矛 (spear)",
        PRESET_LOG = "木头 (log)",
        PRESET_CUTGRASS = "草 (cutgrass)",
        PRESET_TWIGS = "树枝 (twigs)",
        PRESET_ROCKS = "石头 (rocks)",
        PRESET_FLINT = "燧石 (flint)",
        PRESET_GOLDNUGGET = "金块 (goldnugget)",

        -- 键盘按键
        KEY_SPACE = "空格",
        KEY_ENTER = "回车",
        KEY_ESCAPE = "Esc",
        KEY_TAB = "Tab",
        KEY_BACKSPACE = "退格",

        -- 装备槽位
        SLOT_HAND = "手部",
        SLOT_HEAD = "头部",
        SLOT_BODY = "身体",
    },
}

-- 获取当前语言代码
function Localization.GetCurrentLanguage()
    local LOC = _G.LOC or G.LOC
    if LOC then
        local lang_id = LOC.GetLanguage and LOC.GetLanguage()
        if lang_id then
            local LANGUAGE = _G.LANGUAGE or G.LANGUAGE
            if LANGUAGE then
                -- 中文（简体和繁体）使用中文字符串
                if lang_id == LANGUAGE.CHINESE_S or
                   lang_id == LANGUAGE.CHINESE_T or
                   lang_id == LANGUAGE.CHINESE_S_RAIL then
                    return "zh"
                end
            end
        end
    end
    -- 默认英文
    return "en"
end

-- 获取本地化字符串
function Localization.GetString(key)
    local lang = Localization.GetCurrentLanguage()
    local strings = STRINGS_TABLE[lang] or STRINGS_TABLE.en
    return strings[key] or STRINGS_TABLE.en[key] or key
end

-- 格式化字符串（支持 %d, %s 等占位符）
function Localization.FormatString(key, ...)
    local str = Localization.GetString(key)
    if select("#", ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

-- 便捷函数
local function L(key, ...)
    return Localization.FormatString(key, ...)
end

-- 导出
Localization.L = L
Localization.STRINGS = STRINGS_TABLE

return Localization
