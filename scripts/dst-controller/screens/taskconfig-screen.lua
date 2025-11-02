-- Task Configuration Screen
-- HUD界面用于配置按钮组合任务

local G = require("dst-controller/global")
local Layout = require("dst-controller/utils/layout")

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local ScrollableList = require("widgets/scrollablelist")
local Spinner = require("widgets/spinner")
local HeaderTabs = require("widgets/redux/headertabs")

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

-- 可用的动作列表（Spinner 使用 text 字段显示）
local AVAILABLE_ACTIONS = {
    -- 无参数动作
    {data = "", text = "【无动作】", has_param = false},
    {data = "attack", text = "攻击", has_param = false},
    {data = "force_attack", text = "强制攻击", has_param = false},
    {data = "examine", text = "检查", has_param = false},
    {data = "inspect_self", text = "检查自己", has_param = false},
    {data = "save_hand_item", text = "保存手持物品", has_param = false},
    {data = "restore_hand_item", text = "恢复手持物品", has_param = false},
    {data = "start_channeling", text = "开始持续动作", has_param = false},
    {data = "stop_channeling", text = "停止持续动作", has_param = false},
    {data = "cycle_head", text = "切换头部装备", has_param = false},
    {data = "cycle_hand", text = "切换手部装备", has_param = false},
    {data = "cycle_body", text = "切换身体装备", has_param = false},

    -- 需要参数的动作
    {data = "equip_item", text = "装备物品 [需要参数]", has_param = true},
    {data = "use_item", text = "使用物品 [需要参数]", has_param = true},
    {data = "use_item_on_self", text = "对自己使用物品 [需要参数]", has_param = true},
    {data = "craft_item", text = "制作物品 [需要参数]", has_param = true},
}

-- 常用物品参数预设（Spinner 使用 text 字段显示）
local ITEM_PRESETS = {
    {data = "", text = "【自定义输入】"},
    {data = "lighter", text = "打火机 (lighter)"},
    {data = "torch", text = "火把 (torch)"},
    {data = "lantern", text = "提灯 (lantern)"},
    {data = "pickaxe", text = "镐子 (pickaxe)"},
    {data = "axe", text = "斧头 (axe)"},
    {data = "shovel", text = "铲子 (shovel)"},
    {data = "hammer", text = "锤子 (hammer)"},
    {data = "spear", text = "长矛 (spear)"},
    {data = "log", text = "木头 (log)"},
    {data = "cutgrass", text = "草 (cutgrass)"},
    {data = "twigs", text = "树枝 (twigs)"},
    {data = "rocks", text = "石头 (rocks)"},
    {data = "flint", text = "燧石 (flint)"},
    {data = "goldnugget", text = "金块 (goldnugget)"},
}

local TaskConfigScreen = G.Class(Screen, function(self, tasks_data, settings_data, on_apply_cb)
    Screen._ctor(self, "TaskConfigScreen")

    self.tasks_data = tasks_data or {}
    self.settings_data = settings_data or {
        attack_angle_mode = "forward_only",
        interaction_angle_mode = "forward_only",
        force_attack_mode = "hostile_only"
    }
    self.on_apply_cb = on_apply_cb
    self.is_dirty = false
    self.current_tab = "tasks"  -- "tasks" 或 "settings"

    -- 主容器
    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板（增大窗口）
    local bottom_buttons = {
        {text = "应用", cb = function() self:Apply() end},
        {text = "关闭", cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        700, 500,
        "控制器配置",
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
end)

function TaskConfigScreen:BuildTabs()
    -- 使用 HeaderTabs 创建标签页
    local tab_items = {
        {text = "任务配置", cb = function() self:SwitchTab("tasks") end},
        {text = "Mod设置", cb = function() self:SwitchTab("settings") end},
    }

    self.tabs = self.root:AddChild(HeaderTabs(tab_items, false))
    self.tabs:SetPosition(0, 225)

    -- 设置 tabs 和底部按钮之间的导航（会在 SwitchTab 中动态更新）
    self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)
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
        self:BuildTasksContent()
    else
        self.tabs:SelectButton(2)
        self:BuildSettingsContent()
    end

    -- 恢复焦点到新内容的第一个可聚焦元素
    if self.scroll_list and tab_type == "tasks" then
        self.scroll_list:SetFocus()
    elseif self.setting_widgets and #self.setting_widgets > 0 and tab_type == "settings" then
        self.setting_widgets[1]:SetFocus()
    end
end

function TaskConfigScreen:BuildTasksContent()
    -- 创建任务配置界面（原有功能）
    self:BuildConfigWidgets()

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
        self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.config_widgets[1])
        self.tabs.menu:SetFocusChangeDir(G.MOVE_RIGHT, self.scroll_list)

        -- ScrollableList 向上到 Tabs，向下到底部按钮
        self.config_widgets[1]:SetFocusChangeDir(G.MOVE_UP, self.tabs.menu)
        self.config_widgets[#self.config_widgets]:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)

        -- ScrollableList 向右到底部按钮, 向左到 tabs
        self.scroll_list:SetFocusChangeDir(G.MOVE_RIGHT, self.apply_button)
        self.scroll_list:SetFocusChangeDir(G.MOVE_LEFT, self.tabs.menu)

        -- 底部按钮向上到 ScrollableList
        self.apply_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
        self.close_button:SetFocusChangeDir(G.MOVE_UP, self.scroll_list)
    else
        -- 空列表时，tabs 直接连接到底部按钮
        self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)
    end
end

function TaskConfigScreen:BuildSettingsContent()
    -- 创建 Mod 设置界面
    self.setting_widgets = {}

    -- 攻击角度模式设置
    local attack_angle_widget = self.content_panel:AddChild(Widget("attack_angle"))
    local attack_angle_label = attack_angle_widget:AddChild(Text(G.NEWFONT, 30, "攻击目标选择范围"))
    attack_angle_label:SetColour(1, 1, 1, 1)
    attack_angle_label:SetHAlign(G.ANCHOR_LEFT)

    local attack_angle_options = {
        {text = "仅前方", data = "forward_only"},
        {text = "360度全方位", data = "all_around"},
    }
    local attack_angle_spinner = attack_angle_widget:AddChild(Spinner(
        attack_angle_options,
        200, 45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true  -- lean=true 使用简洁样式（透明背景）
    ))
    -- lean 样式默认已经是白色文字，不需要额外设置

    -- 设置初始值
    local current_attack_angle = self.settings_data.attack_angle_mode or "forward_only"
    attack_angle_spinner:SetSelected(current_attack_angle)

    -- 设置回调
    attack_angle_spinner.onchangedfn = function(selected_data)
        self.settings_data.attack_angle_mode = selected_data
        self.is_dirty = true
    end

    attack_angle_widget.attack_angle_spinner = attack_angle_spinner
    attack_angle_widget.focus_forward = attack_angle_spinner

    -- 攻击目标过滤设置
    local force_attack_widget = self.content_panel:AddChild(Widget("force_attack"))
    local force_attack_label = force_attack_widget:AddChild(Text(G.NEWFONT, 30, "攻击目标过滤"))
    force_attack_label:SetColour(1, 1, 1, 1)
    force_attack_label:SetHAlign(G.ANCHOR_LEFT)

    local force_attack_options = {
        {text = "仅敌对 (LB+X强攻)", data = "hostile_only"},
        {text = "全部可攻击", data = "force_attack"},
    }
    local force_attack_spinner = force_attack_widget:AddChild(Spinner(
        force_attack_options,
        280, 45,  -- 增加宽度以容纳长文本
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true  -- lean=true 使用简洁样式（透明背景）
    ))
    -- lean 样式默认已经是白色文字，不需要额外设置

    -- 设置初始值
    local current_force_attack = self.settings_data.force_attack_mode or "hostile_only"
    force_attack_spinner:SetSelected(current_force_attack)

    -- 设置回调
    force_attack_spinner.onchangedfn = function(selected_data)
        self.settings_data.force_attack_mode = selected_data
        self.is_dirty = true
    end

    force_attack_widget.force_attack_spinner = force_attack_spinner
    force_attack_widget.focus_forward = force_attack_spinner

    -- 交互目标选择范围设置
    local interaction_angle_widget = self.content_panel:AddChild(Widget("interaction_angle"))
    local interaction_angle_label = interaction_angle_widget:AddChild(Text(G.NEWFONT, 30, "交互目标选择范围"))
    interaction_angle_label:SetColour(1, 1, 1, 1)
    interaction_angle_label:SetHAlign(G.ANCHOR_LEFT)

    local interaction_angle_options = {
        {text = "仅前方", data = "forward_only"},
        {text = "360度全方位", data = "all_around"},
    }
    local interaction_angle_spinner = interaction_angle_widget:AddChild(Spinner(
        interaction_angle_options,
        200, 45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true  -- lean=true 使用简洁样式（透明背景）
    ))

    -- 设置初始值
    local current_interaction_angle = self.settings_data.interaction_angle_mode or "forward_only"
    interaction_angle_spinner:SetSelected(current_interaction_angle)

    -- 设置回调
    interaction_angle_spinner.onchangedfn = function(selected_data)
        self.settings_data.interaction_angle_mode = selected_data
        self.is_dirty = true
    end

    interaction_angle_widget.interaction_angle_spinner = interaction_angle_spinner
    interaction_angle_widget.focus_forward = interaction_angle_spinner

    -- 虚拟光标启用设置
    local vcursor_widget = self.content_panel:AddChild(Widget("virtual_cursor"))
    local vcursor_label = vcursor_widget:AddChild(Text(G.NEWFONT, 30, "虚拟光标"))
    vcursor_label:SetColour(1, 1, 1, 1)
    vcursor_label:SetHAlign(G.ANCHOR_LEFT)

    -- 确保 virtual_cursor_settings 存在
    if not self.settings_data.virtual_cursor_settings then
        self.settings_data.virtual_cursor_settings = {
            enabled = true,
            cursor_speed = 1.0,
            dead_zone = 0.1,
            show_cursor = true,
        }
    end

    local vcursor_options = {
        {text = "禁用", data = false},
        {text = "启用", data = true},
    }
    local vcursor_spinner = vcursor_widget:AddChild(Spinner(
        vcursor_options,
        120, 45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true
    ))

    -- 设置初始值
    vcursor_spinner:SetSelected(self.settings_data.virtual_cursor_settings.enabled)

    -- 设置回调
    vcursor_spinner.onchangedfn = function(selected_data)
        self.settings_data.virtual_cursor_settings.enabled = selected_data
        self.is_dirty = true
    end

    vcursor_widget.vcursor_spinner = vcursor_spinner
    vcursor_widget.focus_forward = vcursor_spinner

    -- 虚拟光标速度设置
    local vcursor_speed_widget = self.content_panel:AddChild(Widget("virtual_cursor_speed"))
    local vcursor_speed_label = vcursor_speed_widget:AddChild(Text(G.NEWFONT, 30, "光标移动速度"))
    vcursor_speed_label:SetColour(1, 1, 1, 1)
    vcursor_speed_label:SetHAlign(G.ANCHOR_LEFT)

    local vcursor_speed_options = {
        {text = "很慢 (0.5x)", data = 0.5},
        {text = "慢 (0.75x)", data = 0.75},
        {text = "正常 (1.0x)", data = 1.0},
        {text = "快 (1.5x)", data = 1.5},
        {text = "很快 (2.0x)", data = 2.0},
    }
    local vcursor_speed_spinner = vcursor_speed_widget:AddChild(Spinner(
        vcursor_speed_options,
        180, 45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true
    ))

    vcursor_speed_spinner:SetSelected(self.settings_data.virtual_cursor_settings.cursor_speed or 1.0)
    vcursor_speed_spinner.onchangedfn = function(selected_data)
        self.settings_data.virtual_cursor_settings.cursor_speed = selected_data
        self.is_dirty = true
    end

    vcursor_speed_widget.vcursor_speed_spinner = vcursor_speed_spinner
    vcursor_speed_widget.focus_forward = vcursor_speed_spinner

    -- 虚拟光标显示设置
    local vcursor_show_widget = self.content_panel:AddChild(Widget("virtual_cursor_show"))
    local vcursor_show_label = vcursor_show_widget:AddChild(Text(G.NEWFONT, 30, "显示光标图标"))
    vcursor_show_label:SetColour(1, 1, 1, 1)
    vcursor_show_label:SetHAlign(G.ANCHOR_LEFT)

    local vcursor_show_options = {
        {text = "隐藏", data = false},
        {text = "显示", data = true},
    }
    local vcursor_show_spinner = vcursor_show_widget:AddChild(Spinner(
        vcursor_show_options,
        120, 45,
        {font = G.NEWFONT, size = 28},
        nil, nil, nil, true
    ))

    vcursor_show_spinner:SetSelected(self.settings_data.virtual_cursor_settings.show_cursor)
    vcursor_show_spinner.onchangedfn = function(selected_data)
        self.settings_data.virtual_cursor_settings.show_cursor = selected_data
        self.is_dirty = true
    end

    vcursor_show_widget.vcursor_show_spinner = vcursor_show_spinner
    vcursor_show_widget.focus_forward = vcursor_show_spinner

    -- 布局所有设置项
    Layout.Vertical({attack_angle_widget, interaction_angle_widget, force_attack_widget, vcursor_widget, vcursor_speed_widget, vcursor_show_widget}, {
        spacing = 50,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 每个设置项内部的布局
    Layout.HorizontalRow({
        {widget = attack_angle_label, width = 250},
        {widget = attack_angle_spinner, width = 200},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    Layout.HorizontalRow({
        {widget = interaction_angle_label, width = 250},
        {widget = interaction_angle_spinner, width = 200},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    Layout.HorizontalRow({
        {widget = force_attack_label, width = 250},
        {widget = force_attack_spinner, width = 280},  -- 更新宽度匹配 Spinner
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    Layout.HorizontalRow({
        {widget = vcursor_label, width = 250},
        {widget = vcursor_spinner, width = 120},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    Layout.HorizontalRow({
        {widget = vcursor_speed_label, width = 250},
        {widget = vcursor_speed_spinner, width = 180},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    Layout.HorizontalRow({
        {widget = vcursor_show_label, width = 250},
        {widget = vcursor_show_spinner, width = 120},
    }, {
        spacing = 30,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    table.insert(self.setting_widgets, attack_angle_widget)
    table.insert(self.setting_widgets, interaction_angle_widget)
    table.insert(self.setting_widgets, force_attack_widget)
    table.insert(self.setting_widgets, vcursor_widget)
    table.insert(self.setting_widgets, vcursor_speed_widget)
    table.insert(self.setting_widgets, vcursor_show_widget)

    -- 设置焦点导航
    attack_angle_widget:SetFocusChangeDir(G.MOVE_DOWN, interaction_angle_widget)
    attack_angle_widget:SetFocusChangeDir(G.MOVE_UP, self.tabs)

    interaction_angle_widget:SetFocusChangeDir(G.MOVE_UP, attack_angle_widget)
    interaction_angle_widget:SetFocusChangeDir(G.MOVE_DOWN, force_attack_widget)

    force_attack_widget:SetFocusChangeDir(G.MOVE_UP, interaction_angle_widget)
    force_attack_widget:SetFocusChangeDir(G.MOVE_DOWN, vcursor_widget)

    vcursor_widget:SetFocusChangeDir(G.MOVE_UP, force_attack_widget)
    vcursor_widget:SetFocusChangeDir(G.MOVE_DOWN, vcursor_speed_widget)

    vcursor_speed_widget:SetFocusChangeDir(G.MOVE_UP, vcursor_widget)
    vcursor_speed_widget:SetFocusChangeDir(G.MOVE_DOWN, vcursor_show_widget)

    vcursor_show_widget:SetFocusChangeDir(G.MOVE_UP, vcursor_speed_widget)
    vcursor_show_widget:SetFocusChangeDir(G.MOVE_DOWN, self.apply_button)

    self.tabs.menu:SetFocusChangeDir(G.MOVE_DOWN, attack_angle_widget)
    self.apply_button:SetFocusChangeDir(G.MOVE_UP, vcursor_show_widget)
    self.close_button:SetFocusChangeDir(G.MOVE_UP, vcursor_show_widget)
end

function TaskConfigScreen:BuildConfigWidgets()
    self.config_widgets = {}

    for _, combo_key in ipairs(BUTTON_COMBOS) do
        -- 如果是 HOSTILE_ONLY 模式，跳过 LB_X（用于强制攻击）
        if not (self.settings_data.force_attack_mode == "hostile_only" and combo_key == "LB_X") then
            -- 创建容器 widget，宽度等于 ScrollableList (650)
            local container = Widget("combo_container_" .. combo_key)

            -- 在容器内创建内容 widget
            local widget = container:AddChild(Widget("combo_" .. combo_key))

            local task_config = self.tasks_data[combo_key] or {
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
            local info_text = string.format("按下:%d  松开:%d", press_count, release_count)
            local info_label = widget:AddChild(Text(G.NEWFONT, 28, info_text))
            info_label:SetColour(0.4, 0.4, 0.4, 1)  -- 稍微深一点的灰色，提高对比度

            -- 配置按钮
            local config_btn = widget:AddChild(TEMPLATES.StandardButton(
                function() self:OpenDetailConfig(combo_key) end,
                "配置",
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

-- 打开详细配置对话框
function TaskConfigScreen:OpenDetailConfig(combo_key)
    local task_config = self.tasks_data[combo_key] or {
        on_press = {},
        on_release = {}
    }

    -- 创建详细配置界面
    local detail_screen = ActionDetailScreen(
        combo_key,
        BUTTON_NAMES[combo_key],
        task_config,
        function(updated_config)
            self.tasks_data[combo_key] = updated_config
            self.is_dirty = true
            self:RefreshConfigWidgets()
        end
    )

    TheFrontEnd:PushScreen(detail_screen)
end

-- 刷新配置列表显示
function TaskConfigScreen:RefreshConfigWidgets()
    -- 清空当前列表
    for _, widget in ipairs(self.config_widgets) do
        widget:Kill()
    end
    self.config_widgets = {}

    -- 重新构建
    self:BuildConfigWidgets()
    self.scroll_list:SetList(self.config_widgets)
end

function TaskConfigScreen:Apply()
    -- 保存任务配置和设置数据
    if self.on_apply_cb then
        self.on_apply_cb(self.tasks_data, self.settings_data)
    end

    self.is_dirty = false
    self:Close()
end

function TaskConfigScreen:Close()
    TheFrontEnd:PopScreen(self)
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
            -- 循环切换：tasks <- settings
            local new_tab = (self.current_tab == "tasks") and "settings" or "tasks"
            self:SwitchTab(new_tab)
            G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        elseif control == G.CONTROL_MENU_R2 then  -- RT (向右切换)
            -- 循环切换：tasks -> settings
            local new_tab = (self.current_tab == "tasks") and "settings" or "tasks"
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
        {text = "+ 添加动作", cb = function() self:AddNewAction() end},
        {text = "确定", cb = function() self:Save() end},
        {text = "取消", cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        750, 550,
        combo_name .. " - 动作配置",  -- title_text：显示在顶部装饰区
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
            600, 300, 70, 10,
            nil, nil, 600/2, nil, nil, nil, nil, nil,
            "GOLD"
        )
    )
    self.scroll_list:SetPosition(0, 50)

    -- 空状态提示文本（当列表为空时显示）
    self.empty_text = self.root:AddChild(Text(G.NEWFONT, 28, "暂无动作\n点击下方 [+ 添加动作] 按钮"))
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
        {text = "按下动作", cb = function() self:SwitchTab("on_press") end},
        {text = "松开动作", cb = function() self:SwitchTab("on_release") end},
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
        "编辑",
        {75, 40}
    ))

    -- 删除按钮
    local delete_btn = widget:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteAction(index) end,
        "删除",
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

    -- 解析现有action
    if action then
        if type(action) == "string" then
            self.action_name = action
        elseif type(action) == "table" and #action >= 1 then
            self.action_name = action[1]
            if #action >= 2 then
                self.action_param = action[2]
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
        {text = "确定", cb = function() self:Save() end},
        {text = "取消", cb = function() self:Close() end},
    }
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(
        600, 400,
        "编辑动作",  -- title_text：显示在顶部装饰区
        bottom_buttons,
        nil,  -- button_spacing：使用默认间距
        nil   -- body_text：不需要 body text
    ))

    -- 从 CurlyWindow 创建的 Menu 中获取按钮引用
    self.save_button = self.bg.actions.items[1]
    self.cancel_button = self.bg.actions.items[2]

    -- 动作类型选择
    local action_label = self.root:AddChild(Text(G.NEWFONT, 32, "动作类型:"))
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

    local param_label = self.param_panel:AddChild(Text(G.NEWFONT, 32, "参数:"))
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

    -- 设置初始值
    self.param_spinner:SetSelected(self.action_param)

    -- 设置回调
    self.param_spinner.onchangedfn = function(selected_data)
        if selected_data == "" then
            -- 显示自定义输入框
            self:ShowCustomInput()
        else
            self.action_param = selected_data
            self:HideCustomInput()
        end
    end

    -- 自定义参数输入框（初始隐藏）
    self.custom_input_panel = self.root:AddChild(Widget("custom_input"))
    self.custom_input_panel:SetPosition(0, -40, 0)
    self.custom_input_panel:Hide()

    local custom_label = self.custom_input_panel:AddChild(Text(G.NEWFONT, 22, "自定义参数:"))
    custom_label:SetColour(1, 1, 1, 1)  -- 白色文字

    -- 这里使用文本显示代替TextEdit（DST的TextEdit比较复杂）
    local input_bg = self.custom_input_panel:AddChild(Image("images/fepanels.xml", "panel_upsell.tex"))

    self.custom_input = self.custom_input_panel:AddChild(Text(G.NEWFONT, 20, self.action_param))
    self.custom_input:SetColour(1, 1, 1, 1)  -- 白色文字

    -- 使用水平布局
    Layout.HorizontalRow({
        {widget = custom_label, width = 120},
        {widget = input_bg, width = 200},
    }, {
        spacing = 20,
        start_x = 0,
        start_y = 0,
        anchor = "center"
    })

    -- 让 custom_input 和 input_bg 重叠（input_bg 是背景）
    self.custom_input:SetPosition(input_bg:GetPosition())

    -- 提示：由于DST限制，这里简化为显示文本
    local hint = self.custom_input_panel:AddChild(Text(G.NEWFONT, 16, "提示：请在参数下拉中选择或在配置文件中手动编辑"))
    hint:SetColour(0.6, 0.6, 0.6, 1)

    Layout.Vertical({hint}, {
        spacing = 0,
        start_x = 0,
        start_y = -20,
        anchor = "top"
    })

    -- 初始化参数面板显示状态
    self:OnActionChanged(self.action_name)

    -- CurlyWindow 已经管理了底部按钮的布局，但需要手动设置 focus navigation

    -- 设置底部按钮之间的水平导航
    self.save_button:SetFocusChangeDir(G.MOVE_RIGHT, self.cancel_button)
    self.cancel_button:SetFocusChangeDir(G.MOVE_LEFT, self.save_button)

    -- 设置 spinners 和底部按钮的导航关系
    self.action_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.param_spinner)
    self.param_spinner:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
    self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
    self.save_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
    self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)

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
        self.param_panel:Show()
        -- 有参数时，action_spinner 向下到 param_spinner
        self.action_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.param_spinner)
        self.param_spinner:SetFocusChangeDir(G.MOVE_UP, self.action_spinner)
        self.param_spinner:SetFocusChangeDir(G.MOVE_DOWN, self.save_button)
        self.save_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
        self.cancel_button:SetFocusChangeDir(G.MOVE_UP, self.param_spinner)
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
