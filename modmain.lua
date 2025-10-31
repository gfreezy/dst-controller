-- Enhanced Controller Mod - Main Entry Point
-- This mod enhances gamepad/controller functionality with custom button combinations

-- ============================================================================
-- Global Environment Setup
-- ============================================================================
-- Import centralized GLOBAL references and initialize with both GLOBAL and env
local G = require("dst-controller/global")
---@diagnostic disable-next-line: undefined-global
G.Init(GLOBAL, env)

-- ============================================================================
-- Load Modules
-- ============================================================================

local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local HookRegistry = require("dst-controller/hooks/registry")

-- ============================================================================
-- Load Saved Configuration
-- ============================================================================

-- Load saved configuration on startup (async)
-- Note: LoadTasksFromFile automatically updates RUNTIME_TASKS and RUNTIME_SETTINGS
ConfigManager.LoadTasksFromFile(function(success, _, _)
    if success then
        print("[Enhanced Controller] Loaded saved configuration from file")
    else
        print("[Enhanced Controller] Using default configuration")
    end
end)

-- ============================================================================
-- Install Hooks
-- ============================================================================

-- Install all hooks via registry (ensures each class is hooked only once)
HookRegistry.InstallAll()

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
