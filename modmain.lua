-- Enhanced Controller Mod - Main Entry Point
-- This mod enhances gamepad/controller functionality with custom button combinations

-- ============================================================================
-- Global Environment Setup
-- ============================================================================
-- Import centralized GLOBAL references and initialize with both GLOBAL and env
local G = require("dst-controller/global")
G.Init(GLOBAL, env)

-- ============================================================================
-- Mod Configuration
-- ============================================================================

local CONFIG = {
    attack_angle_mode = GetModConfigData("attack_angle_mode") or "forward_only",
    force_attack_mode = GetModConfigData("force_attack_mode") or "hostile_only",
}

-- ============================================================================
-- Load Modules
-- ============================================================================

local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local HudHook = require("dst-controller/hooks/hud-hook")
local TargetHook = require("dst-controller/hooks/target-hook")
local ControllerHook = require("dst-controller/hooks/controller-hook")
local InventorybarHook = require("dst-controller/hooks/inventorybar-hook")
local TaskConfigHook = require("dst-controller/hooks/taskconfig-hook")

-- ============================================================================
-- Load Saved Configuration
-- ============================================================================

-- Load saved configuration on startup (async)
ConfigManager.LoadTasksFromFile(function(success, tasks)
    if success then
        print("[Enhanced Controller] Loaded saved configuration from file")
        ConfigManager.UpdateRuntimeTasks(tasks)
    else
        print("[Enhanced Controller] Using default configuration from tasks.lua")
    end
end)

-- ============================================================================
-- Install Hooks
-- ============================================================================

-- Install HUD hook (blocks default actions when modifiers are pressed)
HudHook.Install()

-- Install target selection hook (customizes controller targeting)
TargetHook.Install(CONFIG)

-- Install controller hook (handles button combinations)
ControllerHook.Install()

-- Install inventorybar hook (customizes inventory behavior)
InventorybarHook.Install()

-- Install task config hook (hotkey to open config screen)
TaskConfigHook.Install()

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
