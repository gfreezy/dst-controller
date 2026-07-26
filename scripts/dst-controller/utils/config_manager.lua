-- Config Manager - 配置管理器
-- 处理TASKS配置的加载、保存和运行时更新
local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = {}

-- 配置文件名（保存在客户端数据目录）
local PERSISTENT_FILE_NAME = "enhanced_controller_config.json"
local CONFIG_VERSION = "2.0.0"

local COMBO_KEYS = {
    "LB_A", "LB_B", "LB_X", "LB_Y", "LB_LT", "LB_RT",
    "RB_A", "RB_B", "RB_X", "RB_Y", "RB_LT", "RB_RT",
}

-- 运行时缓存
local RUNTIME_TASKS = nil  -- 默认模式的按键配置
local RUNTIME_VIRTUAL_CURSOR_TASKS = nil  -- 虚拟光标模式的按键配置
local RUNTIME_SETTINGS = nil

-- 加载TASKS配置
---@return table tasks (default mode)
---@return table virtual_cursor_tasks (virtual cursor mode)
function ConfigManager.LoadTasks()
    if RUNTIME_TASKS and RUNTIME_VIRTUAL_CURSOR_TASKS then
        return RUNTIME_TASKS, RUNTIME_VIRTUAL_CURSOR_TASKS
    end

    local success, config = pcall(function()
        return require("dst-controller/config/tasks")
    end)

    if success and config then
        if config.TASKS then
            -- 新格式：返回 {TASKS = ..., VIRTUAL_CURSOR_TASKS = ...}
            RUNTIME_TASKS = ConfigManager.DeepCopy(config.TASKS)
            RUNTIME_VIRTUAL_CURSOR_TASKS = ConfigManager.DeepCopy(config.VIRTUAL_CURSOR_TASKS or config.TASKS)
        else
            -- 旧格式：直接返回 tasks 表
            RUNTIME_TASKS = ConfigManager.DeepCopy(config)
            RUNTIME_VIRTUAL_CURSOR_TASKS = ConfigManager.DeepCopy(config)
        end
        return RUNTIME_TASKS, RUNTIME_VIRTUAL_CURSOR_TASKS
    else
        print("[ConfigManager] Failed to load tasks config, using empty config")
        RUNTIME_TASKS = {}
        RUNTIME_VIRTUAL_CURSOR_TASKS = {}
        return RUNTIME_TASKS, RUNTIME_VIRTUAL_CURSOR_TASKS
    end
end

-- 加载默认设置
function ConfigManager.LoadDefaultSettings()
    return {
        attack_angle_mode = "forward_only",
        force_attack_mode = "hostile_only",
        interaction_angle_mode = "forward_only",
        allow_air_attack = true,            -- 是否允许对着空气攻击（默认开启）
        debug_logging = false,
        auto_crafting_settings = {
            search_radius = 6,
            search_mode = "smart",
            max_containers = 24,
        },
        virtual_cursor_settings = {
            enabled = true,
            toggle_combo = {"LB", "RB", "RT"},
            left_click_key = "LT",
            right_click_key = "RT",
            cursor_speed = 1.0,
            show_cursor = true,
            -- 磁吸设置
            cursor_magnetism = true,        -- 是否启用光标磁吸
            magnetism_range = 2,            -- 磁吸范围 (1=近, 2=中, 3=远)
            target_priority = false,        -- 是否优先吸附玩家附近目标（而不是光标附近）
            actionqueue_integration = true, -- ActionQueue RB3 手柄适配（安装后自动生效）
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

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and
        value ~= math.huge and value ~= -math.huge
end

local function NormalizeAction(action)
    if type(action) == "string" then
        return action ~= "" and action or nil
    end
    if type(action) ~= "table" or type(action[1]) ~= "string" or action[1] == "" then
        return nil
    end

    local normalized = { action[1] }
    for index = 2, math.min(#action, 16) do
        local value = action[index]
        local value_type = type(value)
        if value_type == "string" or value_type == "boolean" or IsFiniteNumber(value) then
            table.insert(normalized, value)
        else
            return nil
        end
    end
    return normalized
end

local function NormalizeActionList(actions)
    local normalized = {}
    if type(actions) ~= "table" then
        return normalized
    end

    -- A corrupted file should not be able to create an unbounded input macro.
    for index = 1, math.min(#actions, 64) do
        local action = NormalizeAction(actions[index])
        if action ~= nil then
            table.insert(normalized, action)
        end
    end
    return normalized
end

function ConfigManager.NormalizeTasks(tasks, defaults)
    tasks = type(tasks) == "table" and tasks or {}
    defaults = type(defaults) == "table" and defaults or {}
    local normalized = {}

    for _, combo_key in ipairs(COMBO_KEYS) do
        local task = type(tasks[combo_key]) == "table" and tasks[combo_key] or nil
        local fallback = type(defaults[combo_key]) == "table" and defaults[combo_key] or {}
        normalized[combo_key] = {
            on_press = NormalizeActionList(task ~= nil and task.on_press or fallback.on_press),
            on_release = NormalizeActionList(task ~= nil and task.on_release or fallback.on_release),
        }
    end
    return normalized
end

local function MergeDefaults(defaults, saved)
    local result = ConfigManager.DeepCopy(defaults)
    if type(saved) ~= "table" then
        return result
    end
    for key, value in pairs(saved) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = MergeDefaults(result[key], value)
        else
            result[key] = ConfigManager.DeepCopy(value)
        end
    end
    return result
end

local function UseEnum(value, allowed, fallback)
    return allowed[value] and value or fallback
end

function ConfigManager.NormalizeSettings(settings)
    local defaults = ConfigManager.LoadDefaultSettings()
    local normalized = MergeDefaults(defaults, settings)

    normalized.attack_angle_mode = UseEnum(normalized.attack_angle_mode,
        { forward_only = true, all_around = true }, defaults.attack_angle_mode)
    normalized.interaction_angle_mode = UseEnum(normalized.interaction_angle_mode,
        { forward_only = true, all_around = true }, defaults.interaction_angle_mode)
    normalized.force_attack_mode = UseEnum(normalized.force_attack_mode,
        { hostile_only = true, force_attack = true }, defaults.force_attack_mode)
    if type(normalized.allow_air_attack) ~= "boolean" then
        normalized.allow_air_attack = defaults.allow_air_attack
    end
    if type(normalized.debug_logging) ~= "boolean" then
        normalized.debug_logging = defaults.debug_logging
    end

    local crafting_defaults = defaults.auto_crafting_settings
    if type(normalized.auto_crafting_settings) ~= "table" then
        normalized.auto_crafting_settings = ConfigManager.DeepCopy(crafting_defaults)
    end
    local crafting = normalized.auto_crafting_settings
    if not IsFiniteNumber(crafting.search_radius) then
        crafting.search_radius = crafting_defaults.search_radius
    end
    crafting.search_radius = math.floor(
        math.max(2, math.min(12, crafting.search_radius)) + 0.5)
    crafting.search_mode = UseEnum(crafting.search_mode,
        { smart = true, thorough = true }, crafting_defaults.search_mode)
    if not IsFiniteNumber(crafting.max_containers) then
        crafting.max_containers = crafting_defaults.max_containers
    end
    crafting.max_containers = math.floor(
        math.max(0, math.min(64, crafting.max_containers)) + 0.5)

    local cursor_defaults = defaults.virtual_cursor_settings
    if type(normalized.virtual_cursor_settings) ~= "table" then
        normalized.virtual_cursor_settings = ConfigManager.DeepCopy(cursor_defaults)
    end
    local cursor = normalized.virtual_cursor_settings
    for _, key in ipairs({
        "enabled", "show_cursor", "cursor_magnetism", "target_priority",
        "actionqueue_integration",
    }) do
        if type(cursor[key]) ~= "boolean" then
            cursor[key] = cursor_defaults[key]
        end
    end
    if not IsFiniteNumber(cursor.cursor_speed) then
        cursor.cursor_speed = cursor_defaults.cursor_speed
    end
    cursor.cursor_speed = math.max(0.1, math.min(3, cursor.cursor_speed))
    if not IsFiniteNumber(cursor.magnetism_range) then
        cursor.magnetism_range = cursor_defaults.magnetism_range
    end
    cursor.magnetism_range = math.floor(math.max(1, math.min(3, cursor.magnetism_range)) + 0.5)

    local valid_buttons = { LB = true, RB = true, LT = true, RT = true, A = true,
        B = true, X = true, Y = true }
    if not valid_buttons[cursor.left_click_key] then
        cursor.left_click_key = cursor_defaults.left_click_key
    end
    if not valid_buttons[cursor.right_click_key] then
        cursor.right_click_key = cursor_defaults.right_click_key
    end
    if type(cursor.toggle_combo) ~= "table" or #cursor.toggle_combo < 2 or #cursor.toggle_combo > 4 then
        cursor.toggle_combo = ConfigManager.DeepCopy(cursor_defaults.toggle_combo)
    else
        local combo = {}
        local seen = {}
        for _, button in ipairs(cursor.toggle_combo) do
            if not valid_buttons[button] or seen[button] then
                combo = nil
                break
            end
            seen[button] = true
            table.insert(combo, button)
        end
        cursor.toggle_combo = combo or ConfigManager.DeepCopy(cursor_defaults.toggle_combo)
    end

    return normalized
end


-- Upgrade legacy persisted shapes before schema normalization. Normalization is
-- intentionally still run afterwards, so future migrations can stay small.
function ConfigManager.MigrateData(data)
    if type(data) ~= "table" then
        return nil
    end
    local migrated = ConfigManager.DeepCopy(data)

    -- Very early backups stored the combo table directly at the root.
    if migrated.tasks == nil and migrated.LB_A ~= nil then
        migrated = { tasks = migrated }
    end
    if type(migrated.tasks) ~= "table" then
        return nil
    end
    if type(migrated.virtual_cursor_tasks) ~= "table" then
        migrated.virtual_cursor_tasks = ConfigManager.DeepCopy(migrated.tasks)
    end
    migrated.version = CONFIG_VERSION
    return migrated
end

function ConfigManager.NormalizeConfig(data)
    local migrated = ConfigManager.MigrateData(data)
    if migrated == nil then
        return nil
    end
    local default_tasks, default_vc_tasks = ConfigManager.LoadDefaultTasks()
    return {
        version = CONFIG_VERSION,
        tasks = ConfigManager.NormalizeTasks(migrated.tasks, default_tasks),
        virtual_cursor_tasks = ConfigManager.NormalizeTasks(
            migrated.virtual_cursor_tasks, default_vc_tasks),
        settings = ConfigManager.NormalizeSettings(migrated.settings),
        timestamp = IsFiniteNumber(migrated.timestamp) and migrated.timestamp or os.time(),
    }
end

-- 保存配置到持久化文件（tasks、virtual_cursor_tasks 和 settings）
function ConfigManager.SaveConfigToFile(tasks, virtual_cursor_tasks, settings, callback)
    local normalized = ConfigManager.NormalizeConfig({
        tasks = tasks,
        virtual_cursor_tasks = virtual_cursor_tasks or tasks,
        settings = settings,
        timestamp = os.time(),
    })
    if normalized == nil then
        if callback then callback(false) end
        return
    end

    -- 更新运行时配置
    RUNTIME_TASKS = ConfigManager.DeepCopy(normalized.tasks)
    RUNTIME_VIRTUAL_CURSOR_TASKS = ConfigManager.DeepCopy(normalized.virtual_cursor_tasks)
    RUNTIME_SETTINGS = ConfigManager.DeepCopy(normalized.settings)
    if Helpers.SetDebugEnabled ~= nil then
        Helpers.SetDebugEnabled(RUNTIME_SETTINGS.debug_logging)
    end

    -- 创建数据结构
    local data = normalized

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
            ConfigManager.PrintConfigToConsole(normalized.tasks)

            if callback then callback(true) end
        end
    )
end

-- 兼容旧方法名
function ConfigManager.SaveTasksToFile(tasks, callback)
    local _, default_vc_tasks = ConfigManager.LoadDefaultTasks()
    ConfigManager.SaveConfigToFile(tasks, default_vc_tasks, ConfigManager.LoadDefaultSettings(), callback)
end

-- 从持久化文件加载配置
function ConfigManager.LoadTasksFromFile(callback)
    G.TheSim:GetPersistentString(
        PERSISTENT_FILE_NAME,
        function(load_success, str)
            if load_success and str ~= nil and str ~= "" then
                -- 尝试解码JSON
                local success, data = pcall(G.json.decode, str)

                local normalized = success and ConfigManager.NormalizeConfig(data) or nil
                if normalized ~= nil then
                    print("[ConfigManager] Configuration loaded from file (version: " .. normalized.version .. ")")

                    -- 更新运行时缓存
                    RUNTIME_TASKS = ConfigManager.DeepCopy(normalized.tasks)
                    RUNTIME_VIRTUAL_CURSOR_TASKS = ConfigManager.DeepCopy(normalized.virtual_cursor_tasks)
                    RUNTIME_SETTINGS = ConfigManager.DeepCopy(normalized.settings)
                    if Helpers.SetDebugEnabled ~= nil then
                        Helpers.SetDebugEnabled(RUNTIME_SETTINGS.debug_logging)
                    end

                    if callback then
                        callback(true, normalized.tasks, normalized.virtual_cursor_tasks,
                            normalized.settings)
                    end
                    return
                else
                    print("[ConfigManager] Failed to decode saved configuration")
                end
            else
                print("[ConfigManager] No saved configuration found")
            end

            -- 加载失败，使用默认配置
            local default_tasks, default_vc_tasks = ConfigManager.LoadDefaultTasks()
            local default_settings = ConfigManager.LoadDefaultSettings()
            if callback then callback(false, default_tasks, default_vc_tasks, default_settings) end
        end
    )
end

-- 加载默认TASKS配置（从tasks.lua）
---@return table tasks (default mode)
---@return table virtual_cursor_tasks (virtual cursor mode)
function ConfigManager.LoadDefaultTasks()
    local success, config = pcall(function()
        return require("dst-controller/config/tasks")
    end)

    if success and config then
        if config.TASKS then
            -- 新格式：返回 {TASKS = ..., VIRTUAL_CURSOR_TASKS = ...}
            return ConfigManager.DeepCopy(config.TASKS), ConfigManager.DeepCopy(config.VIRTUAL_CURSOR_TASKS or config.TASKS)
        else
            -- 旧格式：直接返回 tasks 表
            return ConfigManager.DeepCopy(config), ConfigManager.DeepCopy(config)
        end
    else
        print("[ConfigManager] Failed to load default tasks config, using empty config")
        local empty = ConfigManager.CreateEmptyTasks()
        return empty, ConfigManager.DeepCopy(empty)
    end
end

-- 创建空的TASKS配置
function ConfigManager.CreateEmptyTasks()
    local empty_tasks = {}
    for _, key in ipairs(COMBO_KEYS) do
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
            RUNTIME_VIRTUAL_CURSOR_TASKS = nil
            RUNTIME_SETTINGS = nil
            if Helpers.SetDebugEnabled ~= nil then
                Helpers.SetDebugEnabled(false)
            end
            if callback then callback(true) end
        end
    )
end

-- 获取当前运行时的TASKS配置
---@param is_virtual_cursor boolean 是否为虚拟光标模式
---@return table tasks
function ConfigManager.GetRuntimeTasks(is_virtual_cursor)
    if not RUNTIME_TASKS or not RUNTIME_VIRTUAL_CURSOR_TASKS then
        ConfigManager.LoadTasks()
    end

    if is_virtual_cursor then
        return RUNTIME_VIRTUAL_CURSOR_TASKS or RUNTIME_TASKS
    else
        return RUNTIME_TASKS
    end
end

-- 更新运行时的TASKS配置
---@param tasks table 默认模式配置
---@param virtual_cursor_tasks table 虚拟光标模式配置（可选）
function ConfigManager.UpdateRuntimeTasks(tasks, virtual_cursor_tasks)
    local default_tasks, default_vc_tasks = ConfigManager.LoadDefaultTasks()
    RUNTIME_TASKS = ConfigManager.NormalizeTasks(tasks, default_tasks)
    RUNTIME_VIRTUAL_CURSOR_TASKS = ConfigManager.NormalizeTasks(
        virtual_cursor_tasks or tasks, default_vc_tasks)
end

-- 获取虚拟光标模式的TASKS配置
---@return table virtual_cursor_tasks
function ConfigManager.GetRuntimeVirtualCursorTasks()
    if not RUNTIME_VIRTUAL_CURSOR_TASKS then
        ConfigManager.LoadTasks()
    end
    return RUNTIME_VIRTUAL_CURSOR_TASKS or RUNTIME_TASKS
end

-- 获取当前运行时的设置
function ConfigManager.GetRuntimeSettings()
    if not RUNTIME_SETTINGS then
        RUNTIME_SETTINGS = ConfigManager.LoadDefaultSettings()
        if Helpers.SetDebugEnabled ~= nil then
            Helpers.SetDebugEnabled(RUNTIME_SETTINGS.debug_logging)
        end
    end
    return RUNTIME_SETTINGS
end

-- 更新运行时的设置
function ConfigManager.UpdateRuntimeSettings(settings)
    RUNTIME_SETTINGS = ConfigManager.NormalizeSettings(settings)
    if Helpers.SetDebugEnabled ~= nil then
        Helpers.SetDebugEnabled(RUNTIME_SETTINGS.debug_logging)
    end
end

return ConfigManager
