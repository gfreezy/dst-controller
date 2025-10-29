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
    G.TheInput:AddKeyDownHandler(function(key)
        TaskConfigHook.OnKeyDown(key)
    end)

    -- 监听手柄输入（通过 playercontroller hook）
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
    end)

    print("[TaskConfigHook] Task config hotkey installed")
    print("[TaskConfigHook]   Keyboard: Ctrl+K")
    print("[TaskConfigHook]   Gamepad: LB+RB+Y (同时按下)")
end

-- 处理键盘按键按下事件
function TaskConfigHook.OnKeyDown(key)
    -- Ctrl+K 打开配置界面
    -- KEY_K = 107, KEY_CTRL = 401
    if key == 107 and G.TheInput:IsKeyDown(401) then  -- 107 = K, 401 = CTRL
        if not config_screen_open then
            TaskConfigHook.OpenConfigScreen()
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
    if config_screen_open then
        return
    end

    -- 加载当前TASKS配置
    local tasks = ConfigManager.GetRuntimeTasks()

    -- 创建配置界面
    local screen = TaskConfigScreen(tasks, function(updated_tasks)
        TaskConfigHook.OnApplyConfig(updated_tasks)
    end)

    -- 推入屏幕栈
    G.TheFrontEnd:PushScreen(screen)
    config_screen_open = true

    -- 使用Hook监听界面关闭
    local old_OnDestroy = screen.OnDestroy
    screen.OnDestroy = function(self)
        config_screen_open = false
        if old_OnDestroy then
            old_OnDestroy(self)
        end
    end
end

-- 应用配置
function TaskConfigHook.OnApplyConfig(updated_tasks)
    -- 更新运行时配置（立即生效）
    ConfigManager.UpdateRuntimeTasks(updated_tasks)

    -- 保存到持久化文件
    ConfigManager.SaveTasksToFile(updated_tasks, function(success)
        if success then
            print("[TaskConfigHook] Configuration saved and applied successfully")
        else
            print("[TaskConfigHook] Warning: Failed to save configuration to file")
            print("[TaskConfigHook] Configuration is active but will not persist after restart")
        end
    end)
end

return TaskConfigHook
