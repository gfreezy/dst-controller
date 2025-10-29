-- Task Configuration Screen
-- HUD界面用于配置按钮组合任务

local G = require("global")

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Menu = require("widgets/menu")
local TEMPLATES = require("widgets/templates")
local ScrollableList = require("widgets/scrollablelist")
local Spinner = require("widgets/spinner")

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

-- 可用的动作列表
local AVAILABLE_ACTIONS = {
    -- 无参数动作
    {data = "", description = "【无动作】", has_param = false},
    {data = "attack", description = "攻击", has_param = false},
    {data = "force_attack", description = "强制攻击", has_param = false},
    {data = "examine", description = "检查", has_param = false},
    {data = "inspect_self", description = "检查自己", has_param = false},
    {data = "save_hand_item", description = "保存手持物品", has_param = false},
    {data = "restore_hand_item", description = "恢复手持物品", has_param = false},
    {data = "start_channeling", description = "开始持续动作", has_param = false},
    {data = "stop_channeling", description = "停止持续动作", has_param = false},
    {data = "cycle_head", description = "切换头部装备", has_param = false},
    {data = "cycle_hand", description = "切换手部装备", has_param = false},
    {data = "cycle_body", description = "切换身体装备", has_param = false},

    -- 需要参数的动作
    {data = "equip_item", description = "装备物品 [需要参数]", has_param = true},
    {data = "use_item", description = "使用物品 [需要参数]", has_param = true},
    {data = "use_item_on_self", description = "对自己使用物品 [需要参数]", has_param = true},
    {data = "craft_item", description = "制作物品 [需要参数]", has_param = true},
}

-- 常用物品参数预设
local ITEM_PRESETS = {
    {data = "", description = "【自定义输入】"},
    {data = "lighter", description = "打火机 (lighter)"},
    {data = "torch", description = "火把 (torch)"},
    {data = "lantern", description = "提灯 (lantern)"},
    {data = "pickaxe", description = "镐子 (pickaxe)"},
    {data = "axe", description = "斧头 (axe)"},
    {data = "shovel", description = "铲子 (shovel)"},
    {data = "hammer", description = "锤子 (hammer)"},
    {data = "spear", description = "长矛 (spear)"},
    {data = "log", description = "木头 (log)"},
    {data = "cutgrass", description = "草 (cutgrass)"},
    {data = "twigs", description = "树枝 (twigs)"},
    {data = "rocks", description = "石头 (rocks)"},
    {data = "flint", description = "燧石 (flint)"},
    {data = "goldnugget", description = "金块 (goldnugget)"},
}

local TaskConfigScreen = G.Class(Screen, function(self, tasks_data, on_apply_cb)
    Screen._ctor(self, "TaskConfigScreen")

    self.tasks_data = tasks_data or {}
    self.on_apply_cb = on_apply_cb
    self.config_widgets = {}
    self.is_dirty = false

    -- 半透明黑色背景
    self.black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.black.image:SetVRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetHRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black.image:SetTint(0, 0, 0, 0.75)
    self.black:SetOnClick(function() end)

    -- 主容器
    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(500, 400, 1, 1, 68, -40))
    self.bg.fill = self.root:AddChild(Image("images/fepanel_fills.xml", "panel_fill_tall.tex"))
    self.bg.fill:SetScale(1.1, -0.85)
    self.bg.fill:SetPosition(8, 12)

    -- 标题
    self.title = self.root:AddChild(Text(BUTTONFONT, 50, "控制器任务配置"))
    self.title:SetPosition(0, 220, 0)
    self.title:SetColour(0, 0, 0, 1)

    -- 说明文本
    self.help_text = self.root:AddChild(Text(G.NEWFONT, 22, "点击按钮组合进行详细配置"))
    self.help_text:SetPosition(0, 180, 0)
    self.help_text:SetColour(0, 0, 0, 1)

    -- 配置选项容器
    self.options_panel = self.root:AddChild(Widget("options_panel"))
    self.options_panel:SetPosition(0, 20)

    -- 创建按钮列表
    self:BuildConfigWidgets()

    -- 创建滚动列表
    self.scroll_list = self.options_panel:AddChild(
        ScrollableList(self.config_widgets, 550, 300, 45, 5)
    )
    self.scroll_list:SetPosition(0, 0)

    -- 底部按钮
    local button_y = -220
    self.menu = self.root:AddChild(Menu(nil, 150, true))

    self.apply_button = self.menu:AddItem(
        "应用",
        function() self:Apply() end,
        Vector3(120, button_y, 0)
    )
    self.apply_button:SetScale(0.7)

    self.close_button = self.menu:AddItem(
        "关闭",
        function() self:Close() end,
        Vector3(-120, button_y, 0)
    )
    self.close_button:SetScale(0.7)

    if #self.config_widgets > 0 then
        self.default_focus = self.config_widgets[1]
    else
        self.default_focus = self.close_button
    end
end)

function TaskConfigScreen:BuildConfigWidgets()
    self.config_widgets = {}

    for _, combo_key in ipairs(BUTTON_COMBOS) do
        local widget = Widget("combo_" .. combo_key)

        local task_config = self.tasks_data[combo_key] or {
            on_press = {},
            on_release = {}
        }

        -- 按钮名称
        local label = widget:AddChild(Text(G.NEWFONT, 26, BUTTON_NAMES[combo_key]))
        label:SetPosition(-180, 0, 0)
        label:SetColour(0, 0, 0, 1)
        label:SetHAlign(G.ANCHOR_LEFT)

        -- 显示当前配置的动作数量
        local press_count = #task_config.on_press
        local release_count = #task_config.on_release

        local info_text = string.format("按下:%d个动作  松开:%d个动作", press_count, release_count)
        local info_label = widget:AddChild(Text(G.NEWFONT, 20, info_text))
        info_label:SetPosition(20, 0, 0)
        info_label:SetColour(0.3, 0.3, 0.3, 1)

        -- 配置按钮
        local config_btn = widget:AddChild(TEMPLATES.StandardButton(
            function() self:OpenDetailConfig(combo_key) end,
            "配置",
            {100, 35}
        ))
        config_btn:SetPosition(220, 0, 0)
        config_btn:SetScale(0.6, 0.6)

        widget.focus_forward = config_btn
        widget.combo_key = combo_key
        table.insert(self.config_widgets, widget)
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
    if self.on_apply_cb then
        self.on_apply_cb(self.tasks_data)
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

    if control == G.CONTROL_CANCEL and not down then
        self:Close()
        TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
        return true
    end
end

function TaskConfigScreen:GetHelpText()
    local controller_id = G.TheInput:GetControllerID()
    local t = {}

    if G.TheInput:ControllerAttached() then
        -- 手柄模式
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_ACCEPT) .. " 选择")
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

    -- 背景
    self.black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.black.image:SetVRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetHRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black.image:SetTint(0, 0, 0, 0.85)
    self.black:SetOnClick(function() end)

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(600, 450, 1, 1, 68, -40))
    self.bg.fill = self.root:AddChild(Image("images/fepanel_fills.xml", "panel_fill_tall.tex"))
    self.bg.fill:SetScale(1.3, -0.95)
    self.bg.fill:SetPosition(8, 12)

    -- 标题
    self.title = self.root:AddChild(Text(BUTTONFONT, 45, combo_name .. " - 动作配置"))
    self.title:SetPosition(0, 240, 0)
    self.title:SetColour(0, 0, 0, 1)

    -- 标签页：按下 / 松开
    self:BuildTabs()

    -- 动作列表显示区域
    self.actions_panel = self.root:AddChild(Widget("actions_panel"))
    self.actions_panel:SetPosition(0, 50)

    -- 刷新动作列表
    self:RefreshActionsList()

    -- 底部按钮
    local button_y = -230
    self.menu = self.root:AddChild(Menu(nil, 120, true))

    self.add_action_button = self.menu:AddItem(
        "+ 添加动作",
        function() self:AddNewAction() end,
        Vector3(0, button_y + 50, 0)
    )
    self.add_action_button:SetScale(0.6)

    self.save_button = self.menu:AddItem(
        "保存",
        function() self:Save() end,
        Vector3(120, button_y, 0)
    )
    self.save_button:SetScale(0.7)

    self.cancel_button = self.menu:AddItem(
        "取消",
        function() self:Close() end,
        Vector3(-120, button_y, 0)
    )
    self.cancel_button:SetScale(0.7)

    self.default_focus = self.add_action_button
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
    local tab_y = 190
    local tab_spacing = 150

    -- 按下标签
    self.press_tab_bg = self.root:AddChild(Image("images/fepanels.xml", "panel_upsell.tex"))
    self.press_tab_bg:SetPosition(-tab_spacing/2, tab_y, 0)
    self.press_tab_bg:SetScale(0.4, 0.3)

    self.press_tab = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:SwitchTab("on_press") end,
        "按下动作",
        {140, 40}
    ))
    self.press_tab:SetPosition(-tab_spacing/2, tab_y, 0)
    self.press_tab:SetScale(0.5, 0.5)

    -- 松开标签
    self.release_tab_bg = self.root:AddChild(Image("images/fepanels.xml", "panel_upsell.tex"))
    self.release_tab_bg:SetPosition(tab_spacing/2, tab_y, 0)
    self.release_tab_bg:SetScale(0.4, 0.3)

    self.release_tab = self.root:AddChild(TEMPLATES.StandardButton(
        function() self:SwitchTab("on_release") end,
        "松开动作",
        {140, 40}
    ))
    self.release_tab:SetPosition(tab_spacing/2, tab_y, 0)
    self.release_tab:SetScale(0.5, 0.5)

    self:UpdateTabHighlight()
end

function ActionDetailScreen:SwitchTab(tab_type)
    self.current_edit_type = tab_type
    self:UpdateTabHighlight()
    self:RefreshActionsList()
end

function ActionDetailScreen:UpdateTabHighlight()
    if self.current_edit_type == "on_press" then
        self.press_tab_bg:SetTint(1, 1, 0.7, 1)
        self.release_tab_bg:SetTint(1, 1, 1, 1)
    else
        self.press_tab_bg:SetTint(1, 1, 1, 1)
        self.release_tab_bg:SetTint(1, 1, 0.7, 1)
    end
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
        local empty_text = self.actions_panel:AddChild(Text(G.NEWFONT, 24, "暂无动作，点击下方'添加动作'按钮"))
        empty_text:SetPosition(0, 0, 0)
        empty_text:SetColour(0.5, 0.5, 0.5, 1)
        table.insert(self.action_widgets, empty_text)
    else
        local y_pos = 80
        for i, action in ipairs(actions) do
            local action_widget = self:CreateActionWidget(action, i)
            action_widget:SetPosition(0, y_pos, 0)
            self.actions_panel:AddChild(action_widget)
            table.insert(self.action_widgets, action_widget)
            y_pos = y_pos - 55
        end
    end
end

function ActionDetailScreen:CreateActionWidget(action, index)
    local widget = Widget("action_" .. index)
    local actions = self.task_config[self.current_edit_type]
    local total_count = #actions

    -- 序号
    local num_text = widget:AddChild(Text(G.NEWFONT, 22, tostring(index) .. "."))
    num_text:SetPosition(-280, 0, 0)
    num_text:SetColour(0, 0, 0, 1)

    -- 上移按钮（如果不是第一个）
    if index > 1 then
        local up_btn = widget:AddChild(TEMPLATES.StandardButton(
            function() self:MoveActionUp(index) end,
            "↑",
            {30, 30}
        ))
        up_btn:SetPosition(-240, 0, 0)
        up_btn:SetScale(0.4, 0.4)
    end

    -- 下移按钮（如果不是最后一个）
    if index < total_count then
        local down_btn = widget:AddChild(TEMPLATES.StandardButton(
            function() self:MoveActionDown(index) end,
            "↓",
            {30, 30}
        ))
        down_btn:SetPosition(-205, 0, 0)
        down_btn:SetScale(0.4, 0.4)
    end

    -- 动作显示
    local action_name, action_param = self:ParseAction(action)
    local display_text = action_name
    if action_param then
        display_text = action_name .. "(" .. action_param .. ")"
    end

    local action_text = widget:AddChild(Text(G.NEWFONT, 20, display_text))
    action_text:SetPosition(-60, 0, 0)
    action_text:SetColour(0, 0, 0, 1)
    action_text:SetRegionSize(280, 30)
    action_text:SetHAlign(ANCHOR_LEFT)

    -- 编辑按钮
    local edit_btn = widget:AddChild(TEMPLATES.StandardButton(
        function() self:EditAction(index) end,
        "编辑",
        {70, 30}
    ))
    edit_btn:SetPosition(160, 0, 0)
    edit_btn:SetScale(0.5, 0.5)

    -- 删除按钮
    local delete_btn = widget:AddChild(TEMPLATES.StandardButton(
        function() self:DeleteAction(index) end,
        "删除",
        {70, 30}
    ))
    delete_btn:SetPosition(230, 0, 0)
    delete_btn:SetScale(0.5, 0.5)

    return widget
end

function ActionDetailScreen:ParseAction(action)
    if type(action) == "string" then
        return action, nil
    elseif type(action) == "table" and #action >= 1 then
        local action_name = action[1]
        local params = {}
        for i = 2, #action do
            table.insert(params, tostring(action[i]))
        end
        return action_name, table.concat(params, ", ")
    end
    return "unknown", nil
end

function ActionDetailScreen:AddNewAction()
    -- 弹出动作编辑对话框
    local editor = ActionEditorDialog(nil, function(action)
        table.insert(self.task_config[self.current_edit_type], action)
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

    -- 手柄快捷键：LB/RB 切换标签页
    if G.TheInput:ControllerAttached() then
        if control == G.CONTROL_SCROLLBACK and not down then
            -- LB 切换到按下动作
            self:SwitchTab("on_press")
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
            return true
        elseif control == G.CONTROL_SCROLLFWD and not down then
            -- RB 切换到松开动作
            self:SwitchTab("on_release")
            TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
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
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_SCROLLBACK) .. " 按下动作")
        table.insert(t, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_SCROLLFWD) .. " 松开动作")
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

    -- 背景
    self.black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.black.image:SetVRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetHRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black.image:SetTint(0, 0, 0, 0.9)
    self.black:SetOnClick(function() end)

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(G.ANCHOR_MIDDLE)
    self.root:SetHAnchor(G.ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

    -- 背景面板
    self.bg = self.root:AddChild(TEMPLATES.CurlyWindow(450, 300, 1, 1, 68, -40))
    self.bg.fill = self.root:AddChild(Image("images/fepanel_fills.xml", "panel_fill_tiny.tex"))
    self.bg.fill:SetScale(1.0, -0.65)
    self.bg.fill:SetPosition(8, 12)

    -- 标题
    self.title = self.root:AddChild(Text(BUTTONFONT, 40, "编辑动作"))
    self.title:SetPosition(0, 130, 0)
    self.title:SetColour(0, 0, 0, 1)

    -- 动作类型选择
    local action_label = self.root:AddChild(Text(G.NEWFONT, 24, "动作类型:"))
    action_label:SetPosition(-150, 70, 0)
    action_label:SetColour(0, 0, 0, 1)

    self.action_spinner = self.root:AddChild(
        Spinner(AVAILABLE_ACTIONS, 220, nil, {font=G.NEWFONT, size=20}, nil, nil, nil, true)
    )
    self.action_spinner:SetTextColour(0, 0, 0, 1)
    self.action_spinner:SetPosition(50, 70, 0)
    self.action_spinner:SetSelected(self.action_name)
    self.action_spinner.OnChanged = function(_, data)
        self.action_name = data
        self:OnActionChanged(data)
    end

    -- 参数选择区域（初始隐藏）
    self.param_panel = self.root:AddChild(Widget("param_panel"))
    self.param_panel:SetPosition(0, 10, 0)

    local param_label = self.param_panel:AddChild(Text(G.NEWFONT, 24, "参数:"))
    param_label:SetPosition(-150, 0, 0)
    param_label:SetColour(0, 0, 0, 1)

    self.param_spinner = self.param_panel:AddChild(
        Spinner(ITEM_PRESETS, 220, nil, {font=G.NEWFONT, size=20}, nil, nil, nil, true)
    )
    self.param_spinner:SetTextColour(0, 0, 0, 1)
    self.param_spinner:SetPosition(50, 0, 0)
    self.param_spinner:SetSelected(self.action_param)
    self.param_spinner.OnChanged = function(_, data)
        if data == "" then
            -- 显示自定义输入框
            self:ShowCustomInput()
        else
            self.action_param = data
            self:HideCustomInput()
        end
    end

    -- 自定义参数输入框（初始隐藏）
    self.custom_input_panel = self.root:AddChild(Widget("custom_input"))
    self.custom_input_panel:SetPosition(0, -40, 0)
    self.custom_input_panel:Hide()

    local custom_label = self.custom_input_panel:AddChild(Text(G.NEWFONT, 22, "自定义参数:"))
    custom_label:SetPosition(-150, 0, 0)
    custom_label:SetColour(0, 0, 0, 1)

    -- 这里使用文本显示代替TextEdit（DST的TextEdit比较复杂）
    local input_bg = self.custom_input_panel:AddChild(Image("images/fepanels.xml", "panel_upsell.tex"))
    input_bg:SetPosition(50, 0, 0)
    input_bg:SetScale(0.5, 0.15)

    self.custom_input = self.custom_input_panel:AddChild(Text(G.NEWFONT, 20, self.action_param))
    self.custom_input:SetPosition(50, 0, 0)
    self.custom_input:SetColour(0, 0, 0, 1)

    -- 提示：由于DST限制，这里简化为显示文本
    local hint = self.custom_input_panel:AddChild(Text(G.NEWFONT, 16, "提示：请在参数下拉中选择或在配置文件中手动编辑"))
    hint:SetPosition(0, -20, 0)
    hint:SetColour(0.6, 0.6, 0.6, 1)

    -- 初始化参数面板显示状态
    self:OnActionChanged(self.action_name)

    -- 底部按钮
    local button_y = -120
    self.menu = self.root:AddChild(Menu(nil, 140, true))

    self.save_button = self.menu:AddItem(
        "保存",
        function() self:Save() end,
        Vector3(80, button_y, 0)
    )
    self.save_button:SetScale(0.7)

    self.cancel_button = self.menu:AddItem(
        "取消",
        function() self:Close() end,
        Vector3(-80, button_y, 0)
    )
    self.cancel_button:SetScale(0.7)

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
    else
        self.param_panel:Hide()
        self.custom_input_panel:Hide()
        self.action_param = ""
    end
end

function ActionEditorDialog:ShowCustomInput()
    self.custom_input_panel:Show()
end

function ActionEditorDialog:HideCustomInput()
    self.custom_input_panel:Hide()
end

function ActionEditorDialog:Save()
    if self.action_name == "" or self.action_name == nil then
        -- 空动作，不保存
        self:Close()
        return
    end

    local action
    if self.action_param and self.action_param ~= "" then
        action = {self.action_name, self.action_param}
    else
        action = self.action_name
    end

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
