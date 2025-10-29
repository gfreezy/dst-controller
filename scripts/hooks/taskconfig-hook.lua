-- Task Config Hook - 任务配置界面快捷键钩子
-- 监听快捷键打开配置界面

local TaskConfigScreen = require("screens/taskconfig_screen")
local ConfigManager = require("utils/config_manager")

local TaskConfigHook = {}

-- 配置界面是否打开
local config_screen_open = false

-- 安装快捷键监听器
function TaskConfigHook.Install()
    -- 监听全局按键事件
    TheInput:AddKeyDownHandler(function(key)
        TaskConfigHook.OnKeyDown(key)
    end)

    print("[TaskConfigHook] Task config hotkey installed (Ctrl+K to open)")
end

-- 处理按键按下事件
function TaskConfigHook.OnKeyDown(key)
    -- Ctrl+K 打开配置界面
    -- KEY_K = 107
    if key == 107 and TheInput:IsKeyDown(KEY_CTRL) then
        if not config_screen_open then
            TaskConfigHook.OpenConfigScreen()
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
    TheFrontEnd:PushScreen(screen)
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
