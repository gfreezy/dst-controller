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
local HudHook = require("dst-controller/hooks/hud-hook")
local ControllerHook = require("dst-controller/hooks/controller-hook")
local InventorybarHook = require("dst-controller/hooks/inventorybar-hook")
local TaskConfigHook = require("dst-controller/hooks/taskconfig-hook")
local VirtualCursorHook = require("dst-controller/hooks/virtual-cursor-hook")

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

-- Install HUD hook (blocks default actions when modifiers are pressed)
HudHook.Install()

-- Install controller hook (handles button combinations)
ControllerHook.Install()

-- Install inventorybar hook (customizes inventory behavior)
InventorybarHook.Install()

-- Install task config hook (hotkey to open config screen)
TaskConfigHook.Install()

-- Install virtual cursor hook (gamepad cursor emulation)
VirtualCursorHook.Install()

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
