-- Enhanced Controller Mod - Main Entry Point
-- This mod enhances gamepad/controller functionality with custom button combinations

-- ============================================================================
-- Global Environment Setup
-- ============================================================================
-- Import centralized GLOBAL references and initialize with GLOBAL
local G = require("global")
G.Init(env)

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
local InventorybarHook = require("hooks/inventorybar-hook")

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

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
