-- Config Manager - 配置管理器
-- 处理TASKS配置的加载、保存和运行时更新
local G = require("dst-controller/global")
local ConfigManager = {}

-- 配置文件名（保存在客户端数据目录）
local PERSISTENT_FILE_NAME = "enhanced_controller_config.json"
local CONFIG_VERSION = "1.0.0"

-- 运行时缓存
local RUNTIME_TASKS = nil
local RUNTIME_SETTINGS = nil

-- 加载TASKS配置
function ConfigManager.LoadTasks()
    if RUNTIME_TASKS then
        return RUNTIME_TASKS
    end

    local success, tasks = pcall(function()
        return require("dst-controller/config/tasks")
    end)

    if success and tasks then
        RUNTIME_TASKS = ConfigManager.DeepCopy(tasks)
        return RUNTIME_TASKS
    else
        print("[ConfigManager] Failed to load tasks config, using empty config")
        RUNTIME_TASKS = {}
        return RUNTIME_TASKS
    end
end

-- 加载默认设置
function ConfigManager.LoadDefaultSettings()
    return {
        attack_angle_mode = "forward_only",
        force_attack_mode = "hostile_only",
        interaction_angle_mode = "forward_only",
        virtual_cursor_settings = {
            enabled = true,
            toggle_combo = {"LB", "RB", "RT"},
            left_click_key = "RT",
            right_click_key = "RB",
            cursor_speed = 1.0,
            dead_zone = 0.1,
            show_cursor = true,
        }
    }
end

-- 深拷贝表
function ConfigManager.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[ConfigManager.DeepCopy(orig_key)] = ConfigManager.DeepCopy(orig_value)
        end
        setmetatable(copy, ConfigManager.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 保存配置到持久化文件（tasks 和 settings）
function ConfigManager.SaveConfigToFile(tasks, settings, callback)
    -- 更新运行时配置
    RUNTIME_TASKS = ConfigManager.DeepCopy(tasks)
    RUNTIME_SETTINGS = ConfigManager.DeepCopy(settings)

    -- 创建数据结构
    local data = {
        version = CONFIG_VERSION,
        tasks = tasks,
        settings = settings or ConfigManager.LoadDefaultSettings(),
        timestamp = os.time()
    }

    -- 编码为JSON
    local success, json_str = pcall(G.json.encode, data)

    if not success then
        print("[ConfigManager] Failed to encode configuration to JSON")
        if callback then callback(false) end
        return
    end

    -- 保存到持久化文件
    G.TheSim:SetPersistentString(
        PERSISTENT_FILE_NAME,
        json_str,
        false,
        function()
            print("[ConfigManager] Configuration saved to file: " .. PERSISTENT_FILE_NAME)

            -- 同时打印到控制台作为备份
            ConfigManager.PrintConfigToConsole(tasks)

            if callback then callback(true) end
        end
    )
end

-- 兼容旧方法名
function ConfigManager.SaveTasksToFile(tasks, callback)
    ConfigManager.SaveConfigToFile(tasks, ConfigManager.LoadDefaultSettings(), callback)
end

-- 从持久化文件加载配置
function ConfigManager.LoadTasksFromFile(callback)
    G.TheSim:GetPersistentString(
        PERSISTENT_FILE_NAME,
        function(load_success, str)
            if load_success and str ~= nil and str ~= "" then
                -- 尝试解码JSON
                local success, data = pcall(G.json.decode, str)

                if success and data and data.tasks then
                    print("[ConfigManager] Configuration loaded from file (version: " .. (data.version or "unknown") .. ")")

                    -- 更新运行时缓存
                    RUNTIME_TASKS = ConfigManager.DeepCopy(data.tasks)
                    RUNTIME_SETTINGS = ConfigManager.DeepCopy(data.settings or ConfigManager.LoadDefaultSettings())

                    if callback then callback(true, data.tasks, data.settings) end
                    return
                else
                    print("[ConfigManager] Failed to decode saved configuration")
                end
            else
                print("[ConfigManager] No saved configuration found")
            end

            -- 加载失败，使用默认配置
            local default_tasks = ConfigManager.LoadDefaultTasks()
            local default_settings = ConfigManager.LoadDefaultSettings()
            if callback then callback(false, default_tasks, default_settings) end
        end
    )
end

-- 加载默认TASKS配置（从tasks.lua）
function ConfigManager.LoadDefaultTasks()
    local success, tasks = pcall(function()
        return require("dst-controller/config/tasks")
    end)

    if success and tasks then
        return ConfigManager.DeepCopy(tasks)
    else
        print("[ConfigManager] Failed to load default tasks config, using empty config")
        return ConfigManager.CreateEmptyTasks()
    end
end

-- 创建空的TASKS配置
function ConfigManager.CreateEmptyTasks()
    local empty_tasks = {}
    local combo_keys = {
        "LB_A", "LB_B", "LB_X", "LB_Y", "LB_LT", "LB_RT",
        "RB_A", "RB_B", "RB_X", "RB_Y", "RB_LT", "RB_RT"
    }

    for _, key in ipairs(combo_keys) do
        empty_tasks[key] = {
            on_press = {},
            on_release = {}
        }
    end

    return empty_tasks
end

-- 打印配置到控制台（备份方案）
function ConfigManager.PrintConfigToConsole(tasks)
    local lua_code = ConfigManager.GenerateLuaCode(tasks)

    print("\n========== TASKS CONFIGURATION (BACKUP) ==========")
    print("Configuration has been saved to: client_save/" .. PERSISTENT_FILE_NAME)
    print("If needed, you can manually copy this to: scripts/config/tasks.lua")
    print("==================================================")
    print(lua_code)
    print("==================================================\n")
end

-- 生成Lua代码字符串
function ConfigManager.GenerateLuaCode(tasks)
    local lines = {
        "-- Enhanced Controller - Task Configurations",
        "-- Defines button combination tasks and their actions",
        "",
        "local TASKS = {"
    }

    local combo_order = {
        "LB_A", "LB_B", "LB_X", "LB_Y", "LB_LT", "LB_RT",
        "RB_A", "RB_B", "RB_X", "RB_Y", "RB_LT", "RB_RT"
    }

    for _, combo_key in ipairs(combo_order) do
        local task = tasks[combo_key]
        if task then
            table.insert(lines, "    " .. combo_key .. " = {")

            -- on_press
            table.insert(lines, "        on_press = " .. ConfigManager.SerializeActions(task.on_press) .. ",")

            -- on_release
            table.insert(lines, "        on_release = " .. ConfigManager.SerializeActions(task.on_release) .. ",")

            table.insert(lines, "    },")
        end
    end

    table.insert(lines, "}")
    table.insert(lines, "")
    table.insert(lines, "return TASKS")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

-- 序列化动作列表
function ConfigManager.SerializeActions(actions)
    if not actions or #actions == 0 then
        return "{}"
    end

    local parts = {}
    for _, action in ipairs(actions) do
        if type(action) == "string" then
            table.insert(parts, string.format('"%s"', action))
        elseif type(action) == "table" then
            -- 序列化表格，例如 {"equip_item", "lighter"}
            local inner_parts = {}
            for _, v in ipairs(action) do
                if type(v) == "string" then
                    table.insert(inner_parts, string.format('"%s"', v))
                else
                    table.insert(inner_parts, tostring(v))
                end
            end
            table.insert(parts, "{" .. table.concat(inner_parts, ", ") .. "}")
        end
    end

    if #parts == 0 then
        return "{}"
    elseif #parts == 1 then
        return "{ " .. parts[1] .. " }"
    else
        return "{\n            " .. table.concat(parts, ",\n            ") .. "\n        }"
    end
end

-- 检查配置文件是否存在
function ConfigManager.CheckConfigExists(callback)
    G.TheSim:GetPersistentString(
        PERSISTENT_FILE_NAME,
        function(load_success, str)
            local exists = load_success and str ~= nil and str ~= ""
            if callback then callback(exists) end
        end
    )
end

-- 删除保存的配置文件
function ConfigManager.DeleteSavedConfig(callback)
    G.TheSim:ErasePersistentString(
        PERSISTENT_FILE_NAME,
        function()
            print("[ConfigManager] Saved configuration deleted")
            RUNTIME_TASKS = nil
            if callback then callback(true) end
        end
    )
end

-- 获取当前运行时的TASKS配置
function ConfigManager.GetRuntimeTasks()
    if not RUNTIME_TASKS then
        ConfigManager.LoadTasks()
    end
    return RUNTIME_TASKS
end

-- 更新运行时的TASKS配置
function ConfigManager.UpdateRuntimeTasks(tasks)
    RUNTIME_TASKS = ConfigManager.DeepCopy(tasks)
end

-- 获取当前运行时的设置
function ConfigManager.GetRuntimeSettings()
    if not RUNTIME_SETTINGS then
        RUNTIME_SETTINGS = ConfigManager.LoadDefaultSettings()
    end
    return RUNTIME_SETTINGS
end

-- 更新运行时的设置
function ConfigManager.UpdateRuntimeSettings(settings)
    RUNTIME_SETTINGS = ConfigManager.DeepCopy(settings)
end

return ConfigManager
