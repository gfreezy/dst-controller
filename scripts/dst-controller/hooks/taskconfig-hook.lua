-- Task Config Hook - 任务配置界面快捷键钩子
-- 监听快捷键打开配置界面

local G = require("dst-controller/global")
local TaskConfigScreen = require("dst-controller/screens/taskconfig_screen")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")

local TaskConfigHook = {}

-- 配置界面是否打开
local config_screen_open = false

-- 手柄按钮状态跟踪
local gamepad_buttons_pressed = {
    LB = false,
    RB = false,
    Y = false,
}

-- 安装快捷键监听器
function TaskConfigHook.Install()
    -- 监听全局按键事件（键盘）
    print("[TaskConfigHook] Installing keyboard handler...")
    local handler_installed = G.TheInput:AddKeyHandler(function(key, down)
        if down then  -- 只处理按下事件，忽略释放事件
            print(string.format("[TaskConfigHook] Key pressed: %d", key))
            TaskConfigHook.OnKeyDown(key)
        end
    end)
    print("[TaskConfigHook] Keyboard handler installed:", handler_installed ~= nil)

    -- 监听手柄输入（通过 playercontroller hook）
    print("[TaskConfigHook] Installing playercontroller hook...")
    G.AddComponentPostInit("playercontroller", function(component)
        local old_OnControl = component.OnControl

        component.OnControl = function(self, control, down)
            -- 检查手柄快捷键组合
            TaskConfigHook.OnGamepadControl(control, down)

            -- 调用原始处理
            if old_OnControl then
                return old_OnControl(self, control, down)
            end
        end
        print("[TaskConfigHook] Playercontroller hook installed")
    end)

    print("[TaskConfigHook] Task config hotkey installed")
    print("[TaskConfigHook]   Keyboard: Ctrl+K")
    print("[TaskConfigHook]   Gamepad: LB+RB+Y (同时按下)")
end

-- 处理键盘按键按下事件
function TaskConfigHook.OnKeyDown(key)
    -- Ctrl+K 打开配置界面
    -- KEY_K = 107, KEY_CTRL = 401
    local ctrl_down = G.TheInput:IsKeyDown(401)
    print(string.format("[TaskConfigHook] OnKeyDown - key=%d, K=%s, Ctrl=%s",
        key,
        tostring(key == 107),
        tostring(ctrl_down)))

    if key == 107 and ctrl_down then  -- 107 = K, 401 = CTRL
        print("[TaskConfigHook] Ctrl+K detected! config_screen_open:", config_screen_open)
        if not config_screen_open then
            print("[TaskConfigHook] Opening config screen...")
            TaskConfigHook.OpenConfigScreen()
        else
            print("[TaskConfigHook] Config screen already open, ignoring")
        end
    end
end

-- 处理手柄输入
function TaskConfigHook.OnGamepadControl(control, down)
    -- 更新按钮状态
    if Helpers.IsControlNamedButton(control, "LB") then
        gamepad_buttons_pressed.LB = down
    elseif Helpers.IsControlNamedButton(control, "RB") then
        gamepad_buttons_pressed.RB = down
    elseif Helpers.IsControlNamedButton(control, "Y") then
        gamepad_buttons_pressed.Y = down
    end

    -- 检查 LB+RB+Y 组合（当 Y 按下时检查）
    if down and Helpers.IsControlNamedButton(control, "Y") then
        if gamepad_buttons_pressed.LB and gamepad_buttons_pressed.RB then
            -- LB+RB+Y 同时按下，打开配置界面
            if not config_screen_open then
                print("[TaskConfigHook] Opening config screen via gamepad hotkey (LB+RB+Y)")
                TaskConfigHook.OpenConfigScreen()
            end
        end
    end
end

-- 打开配置界面
function TaskConfigHook.OpenConfigScreen()
    print("[TaskConfigHook] OpenConfigScreen called")

    if config_screen_open then
        print("[TaskConfigHook] Screen already open, aborting")
        return
    end

    -- 加载当前TASKS配置和设置
    print("[TaskConfigHook] Loading runtime tasks...")
    local tasks = ConfigManager.GetRuntimeTasks()
    local settings = ConfigManager.GetRuntimeSettings()
    print("[TaskConfigHook] Tasks loaded:", tasks ~= nil)
    print("[TaskConfigHook] Settings loaded:", settings ~= nil)

    -- 创建配置界面
    print("[TaskConfigHook] Creating TaskConfigScreen...")
    local screen = TaskConfigScreen(tasks, settings, function(updated_tasks, updated_settings)
        TaskConfigHook.OnApplyConfig(updated_tasks, updated_settings)
    end)
    print("[TaskConfigHook] Screen created:", screen ~= nil)

    -- 推入屏幕栈
    print("[TaskConfigHook] Pushing screen to frontend...")
    G.TheFrontEnd:PushScreen(screen)
    config_screen_open = true
    print("[TaskConfigHook] Screen pushed successfully")

    -- 使用Hook监听界面关闭
    local old_OnDestroy = screen.OnDestroy
    screen.OnDestroy = function(self)
        print("[TaskConfigHook] Screen closing...")
        config_screen_open = false
        if old_OnDestroy then
            old_OnDestroy(self)
        end
    end
end

-- 应用配置
function TaskConfigHook.OnApplyConfig(updated_tasks, updated_settings)
    -- 更新运行时配置（立即生效）
    ConfigManager.UpdateRuntimeTasks(updated_tasks)
    ConfigManager.UpdateRuntimeSettings(updated_settings)

    -- 保存到持久化文件
    ConfigManager.SaveConfigToFile(updated_tasks, updated_settings, function(success)
        if success then
            print("[TaskConfigHook] Configuration saved and applied successfully")
        else
            print("[TaskConfigHook] Warning: Failed to save configuration to file")
            print("[TaskConfigHook] Configuration is active but will not persist after restart")
        end
    end)
end

return TaskConfigHook
