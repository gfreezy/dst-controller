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

        -- 动作列表
        ACTION_NONE = "【No Action】",
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
        ACTION_TRIGGER_KEY = "Trigger Key [Needs Param]",

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

        -- 动作列表
        ACTION_NONE = "【无动作】",
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
        ACTION_TRIGGER_KEY = "触发按键 [需要参数]",

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
