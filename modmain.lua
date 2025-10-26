-- Enhanced Controller Mod - Main Entry Point
-- This mod enhances gamepad/controller functionality with custom button combinations

-- ============================================================================
-- Global Environment Setup
-- ============================================================================

local Init = require("core/init")
Init.SetupGlobalEnv()

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

local Helpers = require("utils/helpers")
local HudHook = require("hooks/hud-hook")
local TargetHook = require("hooks/target-hook")
local ControllerHook = require("hooks/controller-hook")

-- Load action and task definitions
local ACTIONS = require("actions/init")  -- Aggregated actions from multiple modules
local TASKS = require("config/tasks")    -- Task configurations

-- ============================================================================
-- Controller Button Mapping
-- ============================================================================

-- Button mapping table - each logical button can map to multiple physical controls
local BUTTON_MAPPINGS = {
    LB = { CONTROL_CAM_AND_INV_MODIFIER },
    RB = { CONTROL_CHARACTER_COMMAND_WHEEL },
    A = { CONTROL_ACCEPT, CONTROL_CONTROLLER_ACTION },
    B = { CONTROL_CANCEL, CONTROL_CONTROLLER_ALTACTION },
    X = { CONTROL_CONTROLLER_ATTACK, CONTROL_PUTSTACK, CONTROL_MENU_MISC_1 },
    Y = { CONTROL_MENU_MISC_2, CONTROL_INSPECT },
    LT = { CONTROL_MAP_ZOOM_IN },
    RT = { CONTROL_OPEN_INVENTORY, CONTROL_MAP_ZOOM_OUT, CONTROL_MENU_R2 },
}

-- ============================================================================
-- Install Hooks
-- ============================================================================

-- Install HUD hook (blocks default actions when modifiers are pressed)
HudHook.Install(BUTTON_MAPPINGS)

-- Install target selection hook (customizes controller targeting)
TargetHook.Install(CONFIG)

-- Install controller hook (handles button combinations)
ControllerHook.Install(BUTTON_MAPPINGS, TASKS, ACTIONS)

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
