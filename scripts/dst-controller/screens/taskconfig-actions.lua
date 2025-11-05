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
    if Helpers.IsComboButtonPressed({"LB", "RB", "Y"}) then
        -- LB+RB+Y 同时按下，打开配置界面
        if down and not config_screen_open then
            print("[TaskConfigHook] Opening config screen via gamepad hotkey (LB+RB+Y)")
            TaskConfigHook.OpenConfigScreen(playerhud)
        end

        return true
    end

    return false
end

-- 打开配置界面
function TaskConfigHook.OpenConfigScreen(playerhud)
    print("[TaskConfigHook] OpenConfigScreen called")

    if config_screen_open then
        print("[TaskConfigHook] Screen already open, aborting")
        return
    end

    -- 加载当前TASKS配置和设置（包括两套按键配置）
    print("[TaskConfigHook] Loading runtime tasks...")
    local tasks = ConfigManager.GetRuntimeTasks(false)  -- 默认模式
    local virtual_cursor_tasks = ConfigManager.GetRuntimeVirtualCursorTasks()  -- 虚拟光标模式
    local settings = ConfigManager.GetRuntimeSettings()
    print("[TaskConfigHook] Tasks loaded:", tasks ~= nil)
    print("[TaskConfigHook] Virtual cursor tasks loaded:", virtual_cursor_tasks ~= nil)
    print("[TaskConfigHook] Settings loaded:", settings ~= nil)

    -- 创建配置界面
    print("[TaskConfigHook] Creating TaskConfigScreen...")
    local screen = TaskConfigScreen(tasks, virtual_cursor_tasks, settings, function(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
        TaskConfigHook.OnApplyConfig(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
    end)
    print("[TaskConfigHook] Screen created:", screen ~= nil)

    -- 使用 PlayerHUD 的 OpenScreenUnderPause 方法
    -- 这会自动在暂停状态下打开屏幕（如果当前没有暂停，会先暂停）
    print("[TaskConfigHook] Opening screen under pause...")
    playerhud:OpenScreenUnderPause(screen)

    config_screen_open = true
    print("[TaskConfigHook] Screen opened successfully")

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
function TaskConfigHook.OnApplyConfig(updated_tasks, updated_virtual_cursor_tasks, updated_settings)
    -- 更新运行时配置（立即生效）
    ConfigManager.UpdateRuntimeTasks(updated_tasks, updated_virtual_cursor_tasks)
    ConfigManager.UpdateRuntimeSettings(updated_settings)

    -- 保存到持久化文件（包括两套按键配置）
    ConfigManager.SaveConfigToFile(updated_tasks, updated_virtual_cursor_tasks, updated_settings, function(success)
        if success then
            print("[TaskConfigHook] Configuration saved and applied successfully")
        else
            print("[TaskConfigHook] Warning: Failed to save configuration to file")
            print("[TaskConfigHook] Configuration is active but will not persist after restart")
        end
    end)
end

return TaskConfigHook
