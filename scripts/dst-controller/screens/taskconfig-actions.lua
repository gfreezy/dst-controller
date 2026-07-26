-- Task Config Hook - 任务配置界面快捷键钩子
-- 监听快捷键打开配置界面

local G = require("dst-controller/global")
local TaskConfigScreen = require("dst-controller.screens.taskconfig-screen")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")

local TaskConfigHook = {}

-- 配置界面是否打开
local config_screen_open = false


-- 处理手柄输入
function TaskConfigHook.OnControl(playerhud, control, down)
    -- 检查 LB+RB+Y 组合（当 Y 按下时检查）
    if Helpers.IsComboButton(control, {"LB", "RB", "Y"}) then
        -- LB+RB+Y 同时按下，打开配置界面
        if down and not config_screen_open then
            Helpers.DebugPrint("Opening config screen via gamepad hotkey (LB+RB+Y)")
            TaskConfigHook.OpenConfigScreen(playerhud)
        end

        return true
    end

    return false
end

-- 打开配置界面
function TaskConfigHook.OpenConfigScreen(playerhud)
    Helpers.DebugPrint("OpenConfigScreen called")

    if config_screen_open then
        Helpers.DebugPrint("Config screen already open")
        return
    end

    -- 加载当前TASKS配置和设置（包括两套按键配置）
    Helpers.DebugPrint("Loading runtime tasks")
    local tasks = ConfigManager.GetRuntimeTasks(false)  -- 默认模式
    local virtual_cursor_tasks = ConfigManager.GetRuntimeVirtualCursorTasks()  -- 虚拟光标模式
    local settings = ConfigManager.GetRuntimeSettings()
    Helpers.DebugPrintf("Tasks loaded: %s", tostring(tasks ~= nil))
    Helpers.DebugPrintf("Virtual cursor tasks loaded: %s",
        tostring(virtual_cursor_tasks ~= nil))
    Helpers.DebugPrintf("Settings loaded: %s", tostring(settings ~= nil))

    -- 创建配置界面
    Helpers.DebugPrint("Creating TaskConfigScreen")
    local screen = TaskConfigScreen(tasks, virtual_cursor_tasks, settings, function(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
        TaskConfigHook.OnApplyConfig(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
    end)
    Helpers.DebugPrintf("Config screen created: %s", tostring(screen ~= nil))

    -- 使用 PlayerHUD 的 OpenScreenUnderPause 方法
    -- 这会自动在暂停状态下打开屏幕（如果当前没有暂停，会先暂停）
    Helpers.DebugPrint("Opening config screen under pause")
    playerhud:OpenScreenUnderPause(screen)

    config_screen_open = true
    Helpers.DebugPrint("Config screen opened")

    -- 使用Hook监听界面关闭
    local old_OnDestroy = screen.OnDestroy
    screen.OnDestroy = function(self)
        Helpers.DebugPrint("Config screen closing")
        config_screen_open = false
        if old_OnDestroy then
            old_OnDestroy(self)
        end
    end
end

-- 应用配置
function TaskConfigHook.OnApplyConfig(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
    -- 更新运行时配置（立即生效）
    ConfigManager.UpdateRuntimeTasks(updated_tasks, updated_virtual_cursor_tasks)
    ConfigManager.UpdateRuntimeSettings(updated_settings)

    -- 保存到持久化文件（包括两套按键配置）
    ConfigManager.SaveConfigToFile(updated_tasks, updated_virtual_cursor_tasks, updated_settings, function(success)
        if success then
            Helpers.DebugPrint("Configuration saved and applied")
        else
            Helpers.DebugPrint("Failed to save configuration to file")
            Helpers.DebugPrint(
                "Configuration is active but will not persist after restart")
        end
    end)
end

return TaskConfigHook
