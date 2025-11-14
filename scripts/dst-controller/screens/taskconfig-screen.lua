-- Task Configuration Screen
-- HUD界面用于配置按钮组合任务

local G = require("dst-controller/global")
local Layout = require("dst-controller/utils/layout")
local L10N = require("dst-controller/localization")
local L = L10N.L

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local ScrollableList = require("widgets/scrollablelist")
local Spinner = require("widgets/spinner")
local HeaderTabs = require("widgets/redux/headertabs")
local ImageButton = require("widgets/imagebutton")

-- 前置声明（避免循环引用警告）
local ActionDetailScreen
local ActionEditorDialog

-- 按钮组合列表
local BUTTON_COMBOS = {
    "LB_A", "LB_B", "LB_X", "LB_Y", "LB_LT", "LB_RT",
    "RB_A", "RB_B", "RB_X", "RB_Y", "RB_LT", "RB_RT",
}

-- 按钮组合的显示名称
local BUTTON_NAMES = {
    LB_A = "LB + A", LB_B = "LB + B", LB_X = "LB + X",
    LB_Y = "LB + Y", LB_LT = "LB + LT", LB_RT = "LB + RT",
    RB_A = "RB + A", RB_B = "RB + B", RB_X = "RB + X",
    RB_Y = "RB + Y", RB_LT = "RB + LT", RB_RT = "RB + RT",
}

-- 动态生成本地化的动作列表和预设（在模块加载时执行一次）
local function GetAvailableActions()
    return {
        -- 无参数动作
        {data = "", text = L("ACTION_NONE"), has_param = false},
        {data = "examine", text = L("ACTION_EXAMINE"), has_param = false},
        {data = "inspect_self", text = L("ACTION_INSPECT_SELF"), has_param = false},
        {data = "use_active_item_on_self", text = L("ACTION_USE_ACTIVE_ITEM_ON_SELF"), has_param = false},
        {data = "use_active_item_on_scene", text = L("ACTION_USE_ACTIVE_ITEM_ON_SCENE"), has_param = false},
        {data = "save_hand_item", text = L("ACTION_SAVE_HAND_ITEM"), has_param = false},
        {data = "restore_hand_item", text = L("ACTION_RESTORE_HAND_ITEM"), has_param = false},
        {data = "start_channeling", text = L("ACTION_START_CHANNELING"), has_param = false},
        {data = "stop_channeling", text = L("ACTION_STOP_CHANNELING"), has_param = false},
        {data = "cycle_head", text = L("ACTION_CYCLE_HEAD"), has_param = false},
        {data = "cycle_hand", text = L("ACTION_CYCLE_HAND"), has_param = false},
        {data = "cycle_body", text = L("ACTION_CYCLE_BODY"), has_param = false},
        {data = "enable_virtual_cursor", text = L("ACTION_ENABLE_VIRTUAL_CURSOR"), has_param = false},
        {data = "disable_virtual_cursor", text = L("ACTION_DISABLE_VIRTUAL_CURSOR"), has_param = false},

        -- 需要参数的动作
        {data = "equip_item", text = L("ACTION_EQUIP_ITEM"), has_param = true},
        {data = "unequip_item", text = L("ACTION_UNEQUIP_ITEM"), has_param = true},
        {data = "use_equip", text = L("ACTION_USE_EQUIP"), has_param = true},
        {data = "use_item_on_self", text = L("ACTION_USE_ITEM_ON_SELF"), has_param = true},
        {data = "use_item_on_scene", text = L("ACTION_USE_ITEM_ON_SCENE"), has_param = true},
        {data = "craft_item", text = L("ACTION_CRAFT_ITEM"), has_param = true},
        {data = "trigger_key", text = L("ACTION_TRIGGER_KEY"), has_param = true},
    }
end

local function GetItemPresets()
    return {
        {data = "", text = L("PRESET_CUSTOM")},
        {data = "lighter", text = L("PRESET_LIGHTER")},
        {data = "torch", text = L("PRESET_TORCH")},
        {data = "lantern", text = L("PRESET_LANTERN")},
        {data = "pickaxe", text = L("PRESET_PICKAXE")},
        {data = "axe", text = L("PRESET_AXE")},
        {data = "shovel", text = L("PRESET_SHOVEL")},
        {data = "hammer", text = L("PRESET_HAMMER")},
        {data = "spear", text = L("PRESET_SPEAR")},
        {data = "log", text = L("PRESET_LOG")},
        {data = "cutgrass", text = L("PRESET_CUTGRASS")},
        {data = "twigs", text = L("PRESET_TWIGS")},
        {data = "rocks", text = L("PRESET_ROCKS")},
        {data = "flint", text = L("PRESET_FLINT")},
        {data = "goldnugget", text = L("PRESET_GOLDNUGGET")},
    }
end

local function GetKeyboardPresets()
    return {
        {data = "", text = L("PRESET_CUSTOM")},
        -- 修饰键
        {data = "ctrl", text = "Ctrl"},
        {data = "shift", text = "Shift"},
        {data = "alt", text = "Alt"},
        {data = "space", text = L("KEY_SPACE")},
        -- 常用组合键
        {data = "ctrl+s", text = "Ctrl+S"},
        {data = "ctrl+shift+s", text = "Ctrl+Shift+S"},
        {data = "ctrl+c", text = "Ctrl+C"},
        {data = "ctrl+v", text = "Ctrl+V"},
        {data = "ctrl+z", text = "Ctrl+Z"},
        {data = "ctrl+y", text = "Ctrl+Y"},
        {data = "ctrl+a", text = "Ctrl+A"},
        {data = "ctrl+f", text = "Ctrl+F"},
        -- 功能键
        {data = "f1", text = "F1"},
        {data = "f2", text = "F2"},
        {data = "f3", text = "F3"},
        {data = "f4", text = "F4"},
        {data = "f5", text = "F5"},
        {data = "f6", text = "F6"},
        {data = "f7", text = "F7"},
        {data = "f8", text = "F8"},
        {data = "f9", text = "F9"},
        {data = "f10", text = "F10"},
        {data = "f11", text = "F11"},
        {data = "f12", text = "F12"},
        -- 特殊键
        {data = "enter", text = L("KEY_ENTER")},
        {data = "escape", text = L("KEY_ESCAPE")},
        {data = "tab", text = L("KEY_TAB")},
        {data = "backspace", text = L("KEY_BACKSPACE")},
    }
end

local function GetEquipSlotPresets()
    return {
        {data = "hand", text = L("SLOT_HAND")},
        {data = "head", text = L("SLOT_HEAD")},
        {data = "body", text = L("SLOT_BODY")},
    }
end

-- 首次加载时生成
local AVAILABLE_ACTIONS = GetAvailableActions()
local ITEM_PRESETS = GetItemPresets()
local KEYBOARD_PRESETS = GetKeyboardPresets()
local EQUIPSLOT_PRESETS = GetEquipSlotPresets()

local TaskConfigScreen = G.Class(Screen, function(self, tasks_data, virtual_cursor_tasks_data, settings_data, on_apply_cb)
    Screen._ctor(self, "TaskConfigScreen")

    self.tasks_data = tasks_data or {}
    self.virtual_cursor_tasks_data = virtual_cursor_tasks_data or {}
    self.settings_data = settings_data or {
        attack_angle_mode = "forward_only",
        interaction_angle_mode = "forward_only",
        force_attack_mode = "hostile_only"
    }
    self.on_apply_cb = on_apply_cb
    self.is_dirty = false
    self.current_tab = "tasks"  -- "tasks", "virtual_cursor", or "settings"

    -- 添加全屏黑色背景阻挡层（模仿 PauseScreen）
    -- 这会阻止玩家点击背景的游戏世界
    self.black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.black.image:SetVRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetHRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black.image:SetTint(0, 0, 0, 0.5)  -- 半透明黑色背景
    self.black:SetOnClick(function() end)  -- 捕获点击事件但不做任何事

    -- 主容器
    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板（增大窗口）
    local bottom_buttons = {
        {text = L("BUTTON_APPLY"), cb = function() self:Apply() end},
        {text = L("BUTTON_CLOSE"), cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        700, 500,
        L("TITLE"),
        bottom_buttons,
        nil
    ))

    -- 从 CurlyWindow 创建的 Menu 中获取按钮引用
    self.apply_button = self.bg.actions.items[1]
    self.close_button = self.bg.actions.items[2]

    -- 设置底部按钮之间的水平导航
    self.apply_button:SetFocusChangeDir(G.MOVE_RIGHT, self.close_button)
    self.close_button:SetFocusChangeDir(G.MOVE_LEFT, self.apply_button)

    -- 创建标签页
    self:BuildTabs()

    -- 内容面板容器
    self.content_panel = self.root:AddChild(Widget("content_panel"))
    self.content_panel:SetPosition(0, 0)

    -- 显示当前标签页内容
    self:SwitchTab("tasks")

    self.default_focus = self.tabs
    
    G.SetAutopaused(true)
end)

function TaskConfigScreen:BuildTabs()
    -- 使用 HeaderTabs 创建标签页
    local tab_items = {
        {text = L("TAB_TASKS"), cb = function() self:SwitchTab("tasks") end},
        {text = L("TAB_VIRTUAL_CURSOR"), cb = function() self:SwitchTab("virtual_cursor") end},
        {text = L("TAB_SETTINGS"), cb = function() self:SwitchTab("settings") end},
    }

    self.tabs = self.root:AddChild(HeaderTabs(tab_items, false))
    self.tabs:SetPosition(0, 225)

    -- 设置 tabs 和底部按钮之间的导航（会在 SwitchTab 中动态更新）
    self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)
    self.tabs:SetFocusChangeDir(G.MOVE_RIGHT, self.apply_button)
    self.apply_button:SetFocusChangeDir(G.MOVE_LEFT, self.tabs)
    self.apply_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
    self.close_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
end

function TaskConfigScreen:SwitchTab(tab_type)
    self.current_tab = tab_type

    -- 清理旧内容
    if self.content_panel then
        self.content_panel:KillAllChildren()
    end

    -- 使用 HeaderTabs 的 SelectButton 方法
    if tab_type == "tasks" then
        self.tabs:SelectButton(1)
        self:BuildTasksContent("tasks")
    elseif tab_type == "virtual_cursor" then
        self.tabs:SelectButton(2)
        self:BuildTasksContent("virtual_cursor")
    else
        self.tabs:SelectButton(3)
        self:BuildSettingsContent()
    end

    -- 恢复焦点到新内容的第一个可聚焦元素
    if self.scroll_list and (tab_type == "tasks" or tab_type == "virtual_cursor") then
        self.scroll_list:SetFocus()
    elseif self.settings_scroll_list and tab_type == "settings" then
        self.settings_scroll_list:SetFocus()
    end
end

function TaskConfigScreen:BuildTasksContent(mode)
    -- mode: "tasks" 或 "virtual_cursor"
    -- 创建任务配置界面
    self:BuildConfigWidgets(mode)

    -- 创建滚动列表
    self.scroll_list = self.content_panel:AddChild(
        ScrollableList(
            self.config_widgets,
            650, 400, 60, 10,
            nil, nil, 650/2, nil, nil, nil, nil, nil,
            "GOLD"
        )
    )
    self.scroll_list:SetPosition(0, 0)
    self.scroll_list:DoFocusHookups()

    -- 设置焦点导航
    if #self.config_widgets > 0 then
        -- Tabs 向下到 ScrollableList
        self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.scroll_list)
        self.tabs:SetFocusChangeDir(G.MOVE_RIGHT, self.scroll_list)

        -- ScrollableList 向上到 Tabs，向下到底部按钮
        self.config_widgets[1]:SetFocusChangeDir(G.MOVE_UP, self.tabs)
        self.config_widgets[#self.config_widgets]:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)

        -- ScrollableList 向右到底部按钮, 向左到 tabs
        self.scroll_list:SetFocusChangeDir(G.MOVE_RIGHT, self.apply_button)
        self.scroll_list:SetFocusChangeDir(G.MOVE_LEFT, self.tabs)

        -- 底部按钮向上到 ScrollableList
        self.apply_button:SetFocusChangeDir(G.MOVE_LEFT, self.scroll_list)
        self.apply_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
        self.close_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
    else
        -- 空列表时，tabs 直接连接到底部按钮
        self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)
    end
end

function TaskConfigScreen:BuildConfigWidgets(mode)
    -- mode: "tasks" 或 "virtual_cursor"
    self.config_widgets = {}

    -- 根据模式选择数据源
    local data_source = mode == "virtual_cursor" and self.virtual_cursor_tasks_data or self.tasks_data

    for _, combo_key in ipairs(BUTTON_COMBOS) do
        -- 如果是 HOSTILE_ONLY 模式，跳过 LB_X（用于强制攻击）
        if not (self.settings_data.force_attack_mode == "hostile_only" and combo_key == "LB_X") then
            -- 创建容器 widget，宽度等于 ScrollableList (650)
            local container = Widget("combo_container_" .. combo_key)

            -- 在容器内创建内容 widget
            local widget = container:AddChild(Widget("combo_" .. combo_key))

            local task_config = data_source[combo_key] or {
                on_press = {},
                on_release = {}
            }

            -- 按钮名称
            local label = widget:AddChild(Text(G.NEWFONT, 35, BUTTON_NAMES[combo_key]))
            label:SetColour(1, 1, 1, 1)
            label:SetHAlign(G.ANCHOR_LEFT)

            -- 显示当前配置的动作数量
            local press_count = #task_config.on_press
            local release_count = #task_config.on_release
            local info_text = L("PRESS_COUNT", press_count, release_count)
            local info_label = widget:AddChild(Text(G.NEWFONT, 28, info_text))
            info_label:SetColour(0.4, 0.4, 0.4, 1)  -- 稍微深一点的灰色，提高对比度

            -- 配置按钮
            local config_btn = widget:AddChild(TEMPLATES.StandardButton(
                function() self:OpenDetailConfig(combo_key, mode) end,
                L("BUTTON_CONFIG"),
                {120, 45}
            ))

            -- 在 widget 内部居中布局
            -- 总宽度：140+220+120 = 480，间距：2×20 = 40，总计 520
            Layout.HorizontalRow({
                {widget = label, width = 140},
                {widget = info_label, width = 220},
                {widget = config_btn, width = 120},
            }, {
                spacing = 20,
                start_x = 0,
                start_y = 0,
                anchor = "center"
            })

            container.focus_forward = config_btn
            container.combo_key = combo_key
            table.insert(self.config_widgets, container)
        end
    end
end

-- 辅助函数：创建单个设置项widget
local function CreateSettingItem(label_text, spinner_options, initial_value, on_change_callback, spinner_width)
    local container = Widget("setting_item")

    -- 创建标签
    local label = container:AddChild(Text(G.NEWFONT, 30, label_text))
    label:SetColour(1, 1, 1, 1)
    label:SetHAlign(G.ANCHOR_LEFT)

    -- 创建Spinner
    local spinner = container:AddChild(Spinner(
        spinner_options,
        spinner_width or 200,
        45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true  -- lean = true: 透明背景，白色文字
    ))

    -- 设置初始值
    spinner:SetSelected(initial_value)

    -- 设置回调
    spinner.onchangedfn = on_change_callback

    -- 布局：标签在左，Spinner在右
    Layout.HorizontalRow({
        {widget = label, width = 250},
        {widget = spinner, width = spinner_width or 200},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 设置焦点转发
    container.focus_forward = spinner

    return container
end

function TaskConfigScreen:BuildSettingsContent()
    -- 创建 Mod 设置界面
    self.setting_widgets = {}

    -- 确保 virtual_cursor_settings 存在
    if not self.settings_data.virtual_cursor_settings then
        self.settings_data.virtual_cursor_settings = {
            enabled = true,
            cursor_speed = 1.0,
            dead_zone = 0.1,
            show_cursor = true,
            cursor_magnetism = true,
            magnetism_range = 2,
            target_priority = false,
        }
    end

    -- 确保磁吸设置存在（兼容旧配置）
    local vc_settings = self.settings_data.virtual_cursor_settings
    if vc_settings.cursor_magnetism == nil then vc_settings.cursor_magnetism = true end
    if vc_settings.magnetism_range == nil then vc_settings.magnetism_range = 2 end
    if vc_settings.target_priority == nil then vc_settings.target_priority = false end

    -- 创建临时设置副本（用于编辑，只有点击应用时才保存）
    self.temp_settings = {
        attack_angle_mode = self.settings_data.attack_angle_mode,
        interaction_angle_mode = self.settings_data.interaction_angle_mode,
        force_attack_mode = self.settings_data.force_attack_mode,
        allow_air_attack = self.settings_data.allow_air_attack ~= false,  -- 默认为 true
        virtual_cursor_settings = {
            enabled = vc_settings.enabled,
            cursor_speed = vc_settings.cursor_speed,
            dead_zone = vc_settings.dead_zone,
            show_cursor = vc_settings.show_cursor,
            cursor_magnetism = vc_settings.cursor_magnetism,
            magnetism_range = vc_settings.magnetism_range,
            target_priority = vc_settings.target_priority,
        }
    }

    -- 创建所有设置项
    local function MakeSettingItemWidgets()
        local items = {}

        -- 1. 攻击角度模式设置
        table.insert(items, CreateSettingItem(
            L("SETTING_ATTACK_ANGLE"),
            {{text = L("OPT_FORWARD_ONLY"), data = "forward_only"}, {text = L("OPT_ALL_AROUND"), data = "all_around"}},
            self.temp_settings.attack_angle_mode or "forward_only",
            function(data) self.temp_settings.attack_angle_mode = data end,
            200
        ))

        -- 2. 交互目标选择范围设置
        table.insert(items, CreateSettingItem(
            L("SETTING_INTERACTION_ANGLE"),
            {{text = L("OPT_FORWARD_ONLY"), data = "forward_only"}, {text = L("OPT_ALL_AROUND"), data = "all_around"}},
            self.temp_settings.interaction_angle_mode or "forward_only",
            function(data) self.temp_settings.interaction_angle_mode = data end,
            200
        ))

        -- 3. 攻击目标过滤设置
        table.insert(items, CreateSettingItem(
            L("SETTING_FORCE_ATTACK"),
            {{text = L("OPT_HOSTILE_ONLY"), data = "hostile_only"}, {text = L("OPT_FORCE_ATTACK"), data = "force_attack"}},
            self.temp_settings.force_attack_mode or "hostile_only",
            function(data) self.temp_settings.force_attack_mode = data end,
            280
        ))

        -- 4. 空气攻击设置
        table.insert(items, CreateSettingItem(
            L("SETTING_AIR_ATTACK"),
            {{text = L("OPT_DISABLED"), data = false}, {text = L("OPT_ENABLED"), data = true}},
            self.temp_settings.allow_air_attack,
            function(data) self.temp_settings.allow_air_attack = data end,
            200
        ))

        -- 5. 虚拟光标启用设置
        local temp_vc = self.temp_settings.virtual_cursor_settings
        table.insert(items, CreateSettingItem(
            L("SETTING_VIRTUAL_CURSOR"),
            {{text = L("OPT_DISABLED"), data = false}, {text = L("OPT_ENABLED"), data = true}},
            temp_vc.enabled,
            function(data) temp_vc.enabled = data end,
            200
        ))

        -- 6. 虚拟光标速度设置
        table.insert(items, CreateSettingItem(
            L("SETTING_CURSOR_SPEED"),
            {
                {text = L("OPT_SPEED_SLOW"), data = 0.5},
                {text = L("OPT_SPEED_SLOWER"), data = 0.75},
                {text = L("OPT_SPEED_NORMAL"), data = 1.0},
                {text = L("OPT_SPEED_FAST"), data = 1.5},
                {text = L("OPT_SPEED_FASTER"), data = 2.0},
            },
            temp_vc.cursor_speed or 1.0,
            function(data) temp_vc.cursor_speed = data end,
            200
        ))

        -- 7. 虚拟光标显示设置
        table.insert(items, CreateSettingItem(
            L("SETTING_SHOW_CURSOR"),
            {{text = L("OPT_HIDE"), data = false}, {text = L("OPT_SHOW"), data = true}},
            temp_vc.show_cursor,
            function(data) temp_vc.show_cursor = data end,
            200
        ))

        -- 8. 光标磁吸启用设置
        table.insert(items, CreateSettingItem(
            L("SETTING_CURSOR_MAGNETISM"),
            {{text = L("OPT_OFF"), data = false}, {text = L("OPT_ON"), data = true}},
            temp_vc.cursor_magnetism,
            function(data) temp_vc.cursor_magnetism = data end,
            200
        ))

        -- 9. 磁吸范围设置
        table.insert(items, CreateSettingItem(
            L("SETTING_MAGNETISM_RANGE"),
            {{text = L("OPT_RANGE_SHORT"), data = 1}, {text = L("OPT_RANGE_MEDIUM"), data = 2}, {text = L("OPT_RANGE_LONG"), data = 3}},
            temp_vc.magnetism_range or 2,
            function(data) temp_vc.magnetism_range = data end,
            200
        ))

        -- 10. 磁吸优先级设置
        table.insert(items, CreateSettingItem(
            L("SETTING_TARGET_PRIORITY"),
            {{text = L("OPT_CURSOR_PRIORITY"), data = false}, {text = L("OPT_PLAYER_PRIORITY"), data = true}},
            temp_vc.target_priority or false,
            function(data) temp_vc.target_priority = data end,
            200
        ))

        return items
    end

    -- 创建ScrollableList
    local items = MakeSettingItemWidgets()

    self.settings_scroll_list = self.content_panel:AddChild(
        ScrollableList(
            items,
            600,  -- width
            400,  -- height
            70,   -- item height
            4,   -- item padding
            nil,  -- update function
            nil,  -- widgets to update
            300,  -- widget X offset (centering)
            nil, nil, nil, nil, nil,
            "GOLD"
        )
    )

    self.settings_scroll_list:SetPosition(0, 0)
    self.settings_scroll_list:DoFocusHookups()

    -- 设置焦点导航（参考 BuildTasksContent）
    if #items > 0 then
        -- Tabs 向下到 ScrollableList
        self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.settings_scroll_list)
        self.tabs:SetFocusChangeDir(G.MOVE_RIGHT, self.settings_scroll_list)

        -- ScrollableList 向上到 Tabs，向下到底部按钮
        items[1]:SetFocusChangeDir(G.MOVE_UP, self.tabs)
        items[#items]:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)

        -- ScrollableList 向右到底部按钮, 向左到 tabs
        self.settings_scroll_list:SetFocusChangeDir(G.MOVE_RIGHT, self.apply_button)
        self.settings_scroll_list:SetFocusChangeDir(G.MOVE_LEFT, self.tabs)

        -- 底部按钮向上到 ScrollableList
        self.apply_button:SetFocusChangeDir(G.MOVE_LEFT, self.settings_scroll_list)
        self.apply_button:SetFocusChangeDir(G.MOVE_UP, self.settings_scroll_list)
        self.close_button:SetFocusChangeDir(G.MOVE_UP, self.settings_scroll_list)
    else
        -- 空列表时，tabs 直接连接到底部按钮
        self.tabs:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)
    end
end

-- 打开详细配置对话框
function TaskConfigScreen:OpenDetailConfig(combo_key, mode)
    -- mode: "tasks" 或 "virtual_cursor"
    local data_source = mode == "virtual_cursor" and self.virtual_cursor_tasks_data or self.tasks_data

    local task_config = data_source[combo_key] or {
        on_press = {},
        on_release = {}
    }

    -- 创建详细配置界面
    local detail_screen = ActionDetailScreen(
        combo_key,
        BUTTON_NAMES[combo_key],
        task_config,
        function(updated_config)
            if mode == "virtual_cursor" then
                self.virtual_cursor_tasks_data[combo_key] = updated_config
            else
                self.tasks_data[combo_key] = updated_config
            end
            self.is_dirty = true
            self:RefreshConfigWidgets(mode)
        end
    )

    TheFrontEnd:PushScreen(detail_screen)
end

-- 刷新配置列表显示
function TaskConfigScreen:RefreshConfigWidgets(mode)
    -- mode: "tasks" 或 "virtual_cursor"
    -- 清空当前列表
    for _, widget in ipairs(self.config_widgets) do
        widget:Kill()
    end

    self.config_widgets = {}

    -- 重新构建
    self:BuildConfigWidgets(mode)
    self.scroll_list:SetList(self.config_widgets)
end

function TaskConfigScreen:Apply()
    -- 将临时设置保存到正式设置数据
    if self.temp_settings then
        -- 复制基础设置
        self.settings_data.attack_angle_mode = self.temp_settings.attack_angle_mode
        self.settings_data.interaction_angle_mode = self.temp_settings.interaction_angle_mode
        self.settings_data.force_attack_mode = self.temp_settings.force_attack_mode
        self.settings_data.allow_air_attack = self.temp_settings.allow_air_attack

        -- 复制虚拟光标设置
        local temp_vc = self.temp_settings.virtual_cursor_settings
        local vc_settings = self.settings_data.virtual_cursor_settings
        vc_settings.enabled = temp_vc.enabled
        vc_settings.cursor_speed = temp_vc.cursor_speed
        vc_settings.dead_zone = temp_vc.dead_zone
        vc_settings.show_cursor = temp_vc.show_cursor
        vc_settings.cursor_magnetism = temp_vc.cursor_magnetism
        vc_settings.magnetism_range = temp_vc.magnetism_range
        vc_settings.target_priority = temp_vc.target_priority

        self.is_dirty = true
    end

    -- 保存任务配置和设置数据（包括两套按键配置）
    if self.on_apply_cb then
        self.on_apply_cb(self.tasks_data, self.virtual_cursor_tasks_data, self.settings_data)
    end

    self.is_dirty = false
    self:Close()
end

function TaskConfigScreen:Close()
    if G.TheWorld then
        G.TheWorld:PushEvent("continuefrompause")
    end

    G.TheFrontEnd:PopScreen(self)
end

function TaskConfigScreen:OnDestroy() 
    G.SetAutopaused(false)
    TaskConfigScreen._base.OnDestroy(self)
end

function TaskConfigScreen:OnControl(control, down)
    if TaskConfigScreen._base.OnControl(self, control, down) then
        return true
    end

    if not down then
        -- Start 键直接应用配置
        if control == G.CONTROL_MENU_START then
            self:Apply()
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        -- LT/RT 快捷切换标签页
        elseif control == G.CONTROL_MENU_L2 then  -- LT (向左切换)
            -- 循环切换：tasks <- virtual_cursor <- settings <- tasks
            local new_tab
            if self.current_tab == "tasks" then
                new_tab = "settings"
            elseif self.current_tab == "virtual_cursor" then
                new_tab = "tasks"
            else  -- settings
                new_tab = "virtual_cursor"
            end
            self:SwitchTab(new_tab)
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        elseif control == G.CONTROL_MENU_R2 then  -- RT (向右切换)
            -- 循环切换：tasks -> virtual_cursor -> settings -> tasks
            local new_tab
            if self.current_tab == "tasks" then
                new_tab = "virtual_cursor"
            elseif self.current_tab == "virtual_cursor" then
                new_tab = "settings"
            else  -- settings
                new_tab = "tasks"
            end
            self:SwitchTab(new_tab)
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        elseif control == G.CONTROL_CANCEL then
            self:Close()
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        end
    end
end

function TaskConfigScreen:GetHelpText()
    local controller_id = G.TheInput:GetControllerID()
    local t = {}

    if G.TheInput:ControllerAttached() then
        -- 手柄模式
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_ACCEPT) .. " 选择")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_MENU_L2) .. "/" ..
                        G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_MENU_R2) .. " 切换标签")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_MENU_START) .. " 应用")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_CANCEL) .. " 关闭")
    else
        -- 键鼠模式
        table.insert(t, "Enter 选择")
        table.insert(t, "ESC 关闭")
    end

    return table.concat(t, "  ")
end

-- ============================================================================
-- 动作详细配置界面
-- ============================================================================

ActionDetailScreen = G.Class(Screen, function(self, combo_key, combo_name, task_config, on_save_cb)
    Screen._ctor(self, "ActionDetailScreen")

    self.combo_key = combo_key
    self.combo_name = combo_name
    self.task_config = {
        on_press = {},
        on_release = {}
    }

    -- 深拷贝配置
    for _, action in ipairs(task_config.on_press or {}) do
        table.insert(self.task_config.on_press, self:CopyAction(action))
    end
    for _, action in ipairs(task_config.on_release or {}) do
        table.insert(self.task_config.on_release, self:CopyAction(action))
    end

    self.on_save_cb = on_save_cb
    self.current_edit_type = "on_press" -- 当前编辑的是 on_press 还是 on_release

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板（增大窗口）
    -- CurlyWindow 参数：sizeX, sizeY, title_text, bottom_buttons, button_spacing, body_text
    local bottom_buttons = {
        {text = L("BUTTON_ADD_ACTION"), cb = function() self:AddNewAction() end},
        {text = L("BUTTON_CONFIRM"), cb = function() self:Save() end},
        {text = L("BUTTON_CANCEL"), cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        750, 550,
        combo_name .. L("DETAIL_TITLE_SUFFIX"),  -- title_text：显示在顶部装饰区
        bottom_buttons,
        nil,  -- button_spacing：使用默认间距
        nil   -- body_text：不需要 body text
    ))

    -- 从 CurlyWindow 创建的 Menu 中获取按钮引用
    self.add_action_button = self.bg.actions.items[1]
    self.save_button = self.bg.actions.items[2]
    self.cancel_button = self.bg.actions.items[3]

    -- 标签页：按下 / 松开
    self:BuildTabs()

    -- 动作列表显示区域（使用 ScrollableList）
    self.action_widgets = {}
    self.scroll_list = self.root:AddChild(
        ScrollableList(
            self.action_widgets,
            600, 300, 70, 4,
            nil, nil, 600/2, nil, nil, nil, nil, nil,
            "GOLD"
        )
    )
    self.scroll_list:SetPosition(0, 50)

    -- 空状态提示文本（当列表为空时显示）
    self.empty_text = self.root:AddChild(Text(G.NEWFONT, 28, L("EMPTY_ACTION_LIST")))
    self.empty_text:SetColour(0.7, 0.7, 0.7, 1)
    self.empty_text:SetRegionSize(500, 100)
    self.empty_text:SetHAlign(ANCHOR_MIDDLE)
    self.empty_text:SetVAlign(ANCHOR_MIDDLE)
    self.empty_text:SetPosition(0, 50)
    self.empty_text:Hide()  -- 初始隐藏

    -- CurlyWindow 已经管理了底部按钮的布局，设置 focus navigation
    -- 设置底部三个按钮之间的水平导航
    self.add_action_button:SetFocusChangeDir(G.MOVE_RIGHT, self.save_button)
    self.save_button:SetFocusChangeDir(G.MOVE_LEFT, self.add_action_button)
    self.save_button:SetFocusChangeDir(G.MOVE_RIGHT, self.cancel_button)
    self.cancel_button:SetFocusChangeDir(G.MOVE_LEFT, self.save_button)

    -- 设置底部按钮向上导航到 tabs（会在 RefreshActionsList 中动态调整）
    self.add_action_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
    self.save_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
    self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)

    -- 设置 tabs 向下导航（会在 RefreshActionsList 中动态调整）
    self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.add_action_button)

    self.default_focus = self.tabs

    -- 刷新动作列表
    self:RefreshActionsList()
end)

function ActionDetailScreen:CopyAction(action)
    if type(action) == "string" then
        return action
    elseif type(action) == "table" then
        local copy = {}
        for i, v in ipairs(action) do
            copy[i] = v
        end
        return copy
    end
    return action
end

function ActionDetailScreen:BuildTabs()
    -- 使用 HeaderTabs 创建标签页
    local tab_items = {
        {text = L("TAB_ON_PRESS"), cb = function() self:SwitchTab("on_press") end},
        {text = L("TAB_ON_RELEASE"), cb = function() self:SwitchTab("on_release") end},
    }

    self.tabs = self.root:AddChild(HeaderTabs(tab_items, false))  -- false = 不循环 focus
    self.tabs:SetPosition(0, 230)

    -- 存储标签引用以便后续访问
    self.press_tab = self.tabs.menu.items[1]
    self.release_tab = self.tabs.menu.items[2]
end

function ActionDetailScreen:SwitchTab(tab_type)
    self.current_edit_type = tab_type

    -- 使用 HeaderTabs 的 SelectButton 方法
    if tab_type == "on_press" then
        self.tabs:SelectButton(1)
    else
        self.tabs:SelectButton(2)
    end

    self:RefreshActionsList()
    -- RefreshActionsList 会根据列表是否为空来设置正确的焦点
    -- 有动作时焦点到 scroll_list，无动作时焦点到 add_action_button
end

function ActionDetailScreen:RefreshActionsList()
    -- 清空现有的动作显示
    if self.action_widgets then
        for _, widget in ipairs(self.action_widgets) do
            widget:Kill()
        end
    end
    self.action_widgets = {}

    local actions = self.task_config[self.current_edit_type]

    if #actions == 0 then
        -- 列表为空，显示空状态文本
        self.empty_text:Show()
        self.scroll_list:Hide()
    else
        -- 列表有内容，隐藏空状态文本，显示 ScrollableList
        self.empty_text:Hide()
        self.scroll_list:Show()

        for i, action in ipairs(actions) do
            local action_widget = self:CreateActionWidget(action, i)
            table.insert(self.action_widgets, action_widget)
        end
    end

    -- 使用 ScrollableList 显示动作列表
    self.scroll_list:SetList(self.action_widgets)

    -- 刷新后重新设置焦点，避免焦点指向已删除的widget
    if #actions > 0 then
        self.scroll_list:SetFocus()
    else
        self.add_action_button:SetFocus()
    end

    -- ScrollableList 会自动处理列表内部的上下导航
    -- 只需设置 ScrollableList 与外部元素的焦点连接
    if #actions > 0 then
        -- Tabs 向下到 ScrollableList
        if self.tabs and self.tabs.menu then
            self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.scroll_list)
            self.tabs.menu:SetFocusChangeDir(G.MOVE_RIGHT, self.scroll_list)
        end

        -- ScrollableList
        self.action_widgets[1]:SetFocusChangeDir(G.MOVE_UP, self.tabs.menu)
        self.action_widgets[#self.action_widgets]:SetFocusChangeDir(G.MOVE_DOWN, self.add_action_button)
        self.scroll_list:SetFocusChangeDir(G.MOVE_LEFT, self.tabs.menu)
        self.scroll_list:SetFocusChangeDir(G.MOVE_RIGHT, self.add_action_button)

        -- 底部按钮向上到 ScrollableList
        self.add_action_button:SetFocusChangeDir(G.MOVE_LEFT, self.scroll_list)
        self.add_action_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
        self.save_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
        self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)

        self.default_focus = self.scroll_list
    else
        -- 空列表时，tabs 向下到添加动作按钮
        if self.tabs and self.tabs.menu then
            self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.add_action_button)
        end

        -- 底部按钮向上到 tabs
        self.add_action_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
        self.save_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)
        self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.tabs)

        self.default_focus = self.add_action_button
    end
end

function ActionDetailScreen:CreateActionWidget(action, index)
    -- 创建容器 widget，宽度等于 ScrollableList (600)
    local container = Widget("action_container_" .. index)

    -- 在容器内创建内容 widget
    local widget = container:AddChild(Widget("action_" .. index))

    local actions = self.task_config[self.current_edit_type]
    local total_count = #actions

    -- 序号
    local num_text = widget:AddChild(Text(G.NEWFONT, 30, tostring(index) .. "."))
    num_text:SetColour(1, 1, 1, 1)  -- 白色文字，适应深色背景

    -- 上移按钮
    local up_btn = nil
    if index > 1 then
        up_btn = widget:AddChild(TEMPLATES.StandardButton(
            function() self:MoveActionUp(index) end,
            "↑",
            {45, 40}
        ))
    end

    -- 下移按钮
    local down_btn = nil
    if index < total_count then
        down_btn = widget:AddChild(TEMPLATES.StandardButton(
            function() self:MoveActionDown(index) end,
            "↓",
            {45, 40}
        ))
    end

    -- 动作显示
    local action_name, action_param = self:ParseAction(action)
    local display_text = action_name
    if action_param then
        display_text = action_name .. "(" .. action_param .. ")"
    end

    local action_text = widget:AddChild(Text(G.NEWFONT, 26, display_text))
    action_text:SetColour(1, 1, 1, 1)  -- 白色文字，适应深色背景
    action_text:SetRegionSize(250, 40)
    action_text:SetHAlign(ANCHOR_LEFT)

    -- 编辑按钮
    local edit_btn = widget:AddChild(TEMPLATES.StandardButton(
        function() self:EditAction(index) end,
        L("BUTTON_EDIT"),
        {75, 40}
    ))

    -- 删除按钮
    local delete_btn = widget:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteAction(index) end,
        L("BUTTON_DELETE"),
        {75, 40}
    ))

    -- 使用水平布局
    -- ScrollableList 宽度 600，总宽度应该等于 600
    -- 顺序：上移/下移按钮 → 序号 → 动作显示 → 编辑 → 删除
    local layout_items = {}

    -- 先添加上移按钮或占位（nil widget 保持宽度用于对齐）
    if up_btn then
        table.insert(layout_items, {widget = up_btn, width = 45})
    else
        table.insert(layout_items, {widget = nil, width = 45})
    end

    -- 添加下移按钮或占位
    if down_btn then
        table.insert(layout_items, {widget = down_btn, width = 45})
    else
        table.insert(layout_items, {widget = nil, width = 45})
    end

    -- 添加序号
    table.insert(layout_items, {widget = num_text, width = 30})

    -- 添加动作显示、编辑、删除按钮
    table.insert(layout_items, {widget = action_text, width = 250})
    table.insert(layout_items, {widget = edit_btn, width = 75})
    table.insert(layout_items, {widget = delete_btn, width = 75})

    -- 在 widget 内部居中布局
    -- 总宽度：45+45+30+250+75+75 = 520，间距：5×10 = 50，总计 570
    Layout.HorizontalRow(layout_items, {
        spacing = 10,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 设置同一行内按钮之间的水平焦点导航
    -- 创建按钮列表（按顺序）
    local buttons = {}
    if up_btn then table.insert(buttons, up_btn) end
    if down_btn then table.insert(buttons, down_btn) end
    table.insert(buttons, edit_btn)
    table.insert(buttons, delete_btn)

    -- 设置按钮之间的左右导航
    for i = 1, #buttons do
        if i > 1 then
            buttons[i]:SetFocusChangeDir(G.MOVE_LEFT, buttons[i-1])
        end
        if i < #buttons then
            buttons[i]:SetFocusChangeDir(G.MOVE_RIGHT, buttons[i+1])
        end
    end

    -- 设置 focus_forward 到第一个按钮（优先编辑按钮，因为最常用）
    container.focus_forward = edit_btn

    return container
end

function ActionDetailScreen:ParseAction(action)
    local action_key = ""
    local action_param = nil

    if type(action) == "string" then
        action_key = action
    elseif type(action) == "table" and #action >= 1 then
        action_key = action[1]
        local params = {}
        for i = 2, #action do
            table.insert(params, tostring(action[i]))
        end
        action_param = table.concat(params, ", ")
    end

    -- 查找中文名称
    local action_name_cn = action_key  -- 默认使用英文名
    for _, action_def in ipairs(AVAILABLE_ACTIONS) do
        if action_def.data == action_key then
            action_name_cn = action_def.text
            -- 移除 [需要参数] 后缀
            action_name_cn = action_name_cn:gsub("%s*%[需要参数%]", "")
            break
        end
    end

    return action_name_cn, action_param
end

function ActionDetailScreen:AddNewAction()
    -- 弹出动作编辑对话框
    local editor = ActionEditorDialog(nil, function(action)
        print("[ActionDetailScreen] AddNewAction callback triggered, action:", action)
        print("[ActionDetailScreen] current_edit_type:", self.current_edit_type)
        print("[ActionDetailScreen] Before insert, action count:", #self.task_config[self.current_edit_type])
        table.insert(self.task_config[self.current_edit_type], action)
        print("[ActionDetailScreen] After insert, action count:", #self.task_config[self.current_edit_type])
        self:RefreshActionsList()
    end)
    TheFrontEnd:PushScreen(editor)
end

function ActionDetailScreen:EditAction(index)
    local actions = self.task_config[self.current_edit_type]
    local action = actions[index]

    local editor = ActionEditorDialog(action, function(new_action)
        actions[index] = new_action
        self:RefreshActionsList()
    end)
    TheFrontEnd:PushScreen(editor)
end

function ActionDetailScreen:DeleteAction(index)
    table.remove(self.task_config[self.current_edit_type], index)
    self:RefreshActionsList()
end

function ActionDetailScreen:MoveActionUp(index)
    if index <= 1 then return end

    local actions = self.task_config[self.current_edit_type]
    -- 交换当前动作和上一个动作
    actions[index], actions[index - 1] = actions[index - 1], actions[index]
    self:RefreshActionsList()
end

function ActionDetailScreen:MoveActionDown(index)
    local actions = self.task_config[self.current_edit_type]
    if index >= #actions then return end

    -- 交换当前动作和下一个动作
    actions[index], actions[index + 1] = actions[index + 1], actions[index]
    self:RefreshActionsList()
end

function ActionDetailScreen:Save()
    if self.on_save_cb then
        self.on_save_cb(self.task_config)
    end
    self:Close()
end

function ActionDetailScreen:Close()
    TheFrontEnd:PopScreen(self)
end

function ActionDetailScreen:OnControl(control, down)
    if ActionDetailScreen._base.OnControl(self, control, down) then
        return true
    end

    if control == G.CONTROL_CANCEL and not down then
        self:Close()
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        return true
    end

    -- 手柄快捷键：LT/RT 循环切换标签页
    if not down then
        if control == G.CONTROL_MENU_L2 then  -- LT (向左切换)
            -- 循环切换：on_press <- on_release
            local new_tab = (self.current_edit_type == "on_press") and "on_release" or "on_press"
            self:SwitchTab(new_tab)
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        elseif control == G.CONTROL_MENU_R2 then  -- RT (向右切换)
            -- 循环切换：on_press -> on_release
            local new_tab = (self.current_edit_type == "on_press") and "on_release" or "on_press"
            self:SwitchTab(new_tab)
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        end
    end
end

function ActionDetailScreen:GetHelpText()
    local controller_id = G.TheInput:GetControllerID()
    local t = {}

    if G.TheInput:ControllerAttached() then
        -- 手柄模式
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_ACCEPT) .. " 选择")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_MENU_L2) .. "/" ..
                        G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_MENU_R2) .. " 切换标签")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_CANCEL) .. " 返回")
    else
        -- 键鼠模式
        table.insert(t, "Enter 选择")
        table.insert(t, "ESC 返回")
    end

    return table.concat(t, "  ")
end

-- ============================================================================
-- 动作编辑对话框
-- ============================================================================

ActionEditorDialog = G.Class(Screen, function(self, action, on_save_cb)
    Screen._ctor(self, "ActionEditorDialog")

    self.on_save_cb = on_save_cb
    self.action_name = ""
    self.action_param = ""

    -- 缓存每个动作的自定义输入内容
    self.custom_input_cache = {}

    -- 解析现有action
    if action then
        if type(action) == "string" then
            self.action_name = action
        elseif type(action) == "table" and #action >= 1 then
            self.action_name = action[1]
            if #action >= 2 then
                self.action_param = action[2]
                -- 将初始参数保存到缓存（如果是自定义参数）
                if self.action_name ~= "" then
                    self.custom_input_cache[self.action_name] = self.action_param
                end
            end
        end
    end

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板（增大窗口）
    -- CurlyWindow 参数：sizeX, sizeY, title_text, bottom_buttons, button_spacing, body_text
    local bottom_buttons = {
        {text = L("BUTTON_CONFIRM"), cb = function() self:Save() end},
        {text = L("BUTTON_CANCEL"), cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        600, 400,
        L("EDITOR_TITLE"),  -- title_text：显示在顶部装饰区
        bottom_buttons,
        nil,  -- button_spacing：使用默认间距
        nil   -- body_text：不需要 body text
    ))

    -- 从 CurlyWindow 创建的 Menu 中获取按钮引用
    self.save_button = self.bg.actions.items[1]
    self.cancel_button = self.bg.actions.items[2]

    -- 动作类型选择
    local action_label = self.root:AddChild(Text(G.NEWFONT, 32, L("LABEL_ACTION_TYPE")))
    action_label:SetColour(1, 1, 1, 1)  -- 白色文字，适应深色背景

    self.action_spinner = self.root:AddChild(
        Spinner(AVAILABLE_ACTIONS, 280, 45, {font=G.NEWFONT, size=28}, nil, nil, nil, true)
    )
    -- lean 样式默认已经是白色文字，不需要额外设置

    -- 使用水平布局
    Layout.HorizontalRow({
        {widget = action_label, width = 120},
        {widget = self.action_spinner, width = 280},
    }, {
        spacing = 20,
        start_x = 0,
        start_y = 100,
        anchor = "center"
    })

    -- 设置初始值
    self.action_spinner:SetSelected(self.action_name)

    -- 设置回调
    self.action_spinner.onchangedfn = function(selected_data)
        self.action_name = selected_data
        self:OnActionChanged(selected_data)
    end

    -- 参数选择区域（初始隐藏）
    self.param_panel = self.root:AddChild(Widget("param_panel"))
    self.param_panel:SetPosition(0, 30, 0)

    local param_label = self.param_panel:AddChild(Text(G.NEWFONT, 32, L("LABEL_PARAM")))
    param_label:SetColour(1, 1, 1, 1)  -- 白色文字

    self.param_spinner = self.param_panel:AddChild(
        Spinner(ITEM_PRESETS, 280, 45, {font=G.NEWFONT, size=28}, nil, nil, nil, true)
    )
    -- lean 样式默认已经是白色文字，不需要额外设置

    -- 使用水平布局
    Layout.HorizontalRow({
        {widget = param_label, width = 80},
        {widget = self.param_spinner, width = 280},
    }, {
        spacing = 20,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 自定义参数输入框（初始隐藏）
    -- 必须在 ShowCustomInput/HideCustomInput 调用之前初始化
    self.custom_input_panel = self.root:AddChild(Widget("custom_input"))
    self.custom_input_panel:SetPosition(0, -40, 0)
    self.custom_input_panel:Hide()

    local custom_label = self.custom_input_panel:AddChild(Text(G.NEWFONT, 28, L("LABEL_CUSTOM_PARAM")))
    custom_label:SetColour(1, 1, 1, 1)  -- 白色文字

    -- 使用 TEMPLATES.StandardSingleLineTextEntry 创建文本输入框
    self.custom_textbox_root = self.custom_input_panel:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, 300, 45))
    self.custom_textbox = self.custom_textbox_root.textbox
    self.custom_textbox:SetTextLengthLimit(50)
    self.custom_textbox:SetForceEdit(false)
    self.custom_textbox:EnableWordWrap(false)
    self.custom_textbox:EnableScrollEditWindow(true)
    self.custom_textbox:SetHelpTextEdit("")
    self.custom_textbox:SetHelpTextApply("")
    self.custom_textbox:SetString(self.action_param ~= "" and self.action_param or "")

    -- 文本输入回调
    self.custom_textbox.OnTextInputted = function()
        local input_text = self.custom_textbox:GetString()
        self.action_param = input_text
        -- 保存到缓存
        if self.action_name and self.action_name ~= "" then
            self.custom_input_cache[self.action_name] = input_text
        end
    end

    -- 使用水平布局
    Layout.HorizontalRow({
        {widget = custom_label, width = 140},
        {widget = self.custom_textbox_root, width = 300},
    }, {
        spacing = 20,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 焦点管理
    self.custom_input_panel:SetOnGainFocus(function() self.custom_textbox:OnGainFocus() end)
    self.custom_input_panel:SetOnLoseFocus(function() self.custom_textbox:OnLoseFocus() end)
    self.custom_input_panel.focus_forward = self.custom_textbox

    -- 设置初始值
    self.param_spinner:SetSelected(self.action_param)
    if self.action_param == "" then
        self:ShowCustomInput()
    else
        self:HideCustomInput()
    end

    -- 设置回调
    self.param_spinner.onchangedfn = function(selected_data)
        if selected_data == "" then
            -- 恢复该动作的缓存输入内容
            local cached_input = self.custom_input_cache[self.action_name] or ""
            self.action_param = cached_input
            self.custom_textbox:SetString(cached_input)
            -- 显示自定义输入框
            self:ShowCustomInput()
            -- 更新焦点导航：param_spinner -> custom_input_panel -> save_button
            self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.custom_input_panel)
            self.custom_input_panel:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
            self.custom_input_panel:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
            self.save_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)
            self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)
        else
            self.action_param = selected_data
            self:HideCustomInput()
            -- 更新焦点导航：param_spinner -> save_button
            self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
            self.save_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
            self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
        end
    end

    -- 初始化参数面板显示状态
    self:OnActionChanged(self.action_name)

    -- CurlyWindow 已经管理了底部按钮的布局，但需要手动设置 focus navigation

    -- 设置底部按钮之间的水平导航
    self.save_button:SetFocusChangeDir(G.MOVE_RIGHT, self.cancel_button)
    self.cancel_button:SetFocusChangeDir(G.MOVE_LEFT, self.save_button)

    -- 设置 spinners、文本输入框和底部按钮的导航关系
    -- 注意：这些是初始设置，会在 OnActionChanged 中根据显示状态动态调整
    self.action_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.param_spinner)
    self.param_spinner:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
    self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.custom_input_panel)
    self.custom_input_panel:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
    self.custom_input_panel:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
    self.save_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)
    self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)

    self.default_focus = self.action_spinner
end)

function ActionEditorDialog:OnActionChanged(action_name)
    -- 查找动作是否需要参数
    local needs_param = false
    for _, action_def in ipairs(AVAILABLE_ACTIONS) do
        if action_def.data == action_name and action_def.has_param then
            needs_param = true
            break
        end
    end

    if needs_param then
        -- 根据动作类型更新参数选择器的选项
        local presets = ITEM_PRESETS  -- 默认使用物品预设
        if action_name == "trigger_key" then
            presets = KEYBOARD_PRESETS
        elseif action_name == "unequip_item" or action_name == "use_equip" then
            presets = EQUIPSLOT_PRESETS
        end

        -- 更新 spinner 的选项
        self.param_spinner:SetOptions(presets)

        -- 确定要选中的参数：优先使用现有参数，否则选中第一个选项
        local selected_param = self.action_param or ""

        -- 检查现有参数是否在 presets 中
        local param_in_presets = false
        if selected_param ~= "" then
            for _, preset in ipairs(presets) do
                if preset.data == selected_param then
                    param_in_presets = true
                    break
                end
            end
        end

        -- 如果现有参数不在 presets 中（自定义参数），则选中空值（"自定义"选项）
        local should_show_input = false
        if not param_in_presets and selected_param ~= "" then
            self.param_spinner:SetSelected("")
            self.custom_textbox:SetString(selected_param)
            should_show_input = true
        elseif selected_param == "" then
            -- 如果没有现有参数，选中第一个选项
            local first_param = presets[1] and presets[1].data or ""
            self.param_spinner:SetSelected(first_param)
            self.action_param = first_param
            -- 恢复该动作的缓存输入内容
            local cached_input = self.custom_input_cache[action_name] or ""
            self.custom_textbox:SetString(cached_input)
            -- 如果第一个选项是空值，则显示输入框
            should_show_input = (first_param == "")
        else
            -- 现有参数在 presets 中，直接选中
            self.param_spinner:SetSelected(selected_param)
            self.custom_textbox:SetString("")
            should_show_input = false
        end

        -- 根据判断结果决定是否显示输入框
        if should_show_input then
            -- 第一个参数为空，显示自定义输入框
            self:ShowCustomInput()
            -- 设置焦点导航：param_spinner -> custom_input_panel -> save_button
            self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.custom_input_panel)
            self.custom_input_panel:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
            self.custom_input_panel:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
            self.save_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)
            self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.custom_input_panel)
        else
            -- 第一个参数不为空，隐藏自定义输入框
            self:HideCustomInput()
            -- 设置焦点导航：param_spinner -> save_button
            self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
            self.save_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
            self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
        end

        self.param_panel:Show()
        -- 有参数时，action_spinner 向下到 param_spinner
        self.action_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.param_spinner)
        self.param_spinner:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
    else
        self.param_panel:Hide()
        self.custom_input_panel:Hide()
        self.action_param = ""
        -- 无参数时，action_spinner 直接向下到 save_button
        self.action_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
        self.save_button:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
        self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
    end
end

function ActionEditorDialog:ShowCustomInput()
    self.custom_input_panel:Show()
end

function ActionEditorDialog:HideCustomInput()
    self.custom_input_panel:Hide()
end

function ActionEditorDialog:Save()
    print("[ActionEditorDialog] Save() called")
    print("[ActionEditorDialog] action_name:", self.action_name)
    print("[ActionEditorDialog] action_param:", self.action_param)

    if self.action_name == "" or self.action_name == nil then
        -- 空动作，不保存
        print("[ActionEditorDialog] Empty action, not saving")
        self:Close()
        return
    end

    local action
    if self.action_param and self.action_param ~= "" then
        action = {self.action_name, self.action_param}
    else
        action = self.action_name
    end

    print("[ActionEditorDialog] Final action:", action)
    print("[ActionEditorDialog] on_save_cb exists:", self.on_save_cb ~= nil)

    if self.on_save_cb then
        self.on_save_cb(action)
    end
    self:Close()
end

function ActionEditorDialog:Close()
    TheFrontEnd:PopScreen(self)
end

function ActionEditorDialog:OnControl(control, down)
    if ActionEditorDialog._base.OnControl(self, control, down) then
        return true
    end

    if control == G.CONTROL_CANCEL and not down then
        self:Close()
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        return true
    end
end

function ActionEditorDialog:GetHelpText()
    local controller_id = G.TheInput:GetControllerID()
    local t = {}

    if G.TheInput:ControllerAttached() then
        -- 手柄模式
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_ACCEPT) .. " 确认")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_CANCEL) .. " 取消")
    else
        -- 键鼠模式
        table.insert(t, "Enter 确认")
        table.insert(t, "ESC 取消")
    end

    return table.concat(t, "  ")
end

return TaskConfigScreen
