-- Enhanced Controller Mod - Main Entry Point
-- This mod enhances gamepad/controller functionality with custom button combinations

-- ============================================================================
-- Global Environment Setup
-- ============================================================================

local Init = require("core/init")
Init.SetupGlobalEnv()

-- ============================================================================
-- Load Modules
-- ============================================================================

local Helpers = require("utils/helpers")
local ButtonHandler = require("core/button-handler")
local ActionExecutor = require("core/action-executor")
local HudHook = require("hooks/hud-hook")
local TargetHook = require("hooks/target-hook")

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
TargetHook.Install()

-- ============================================================================
-- Player Controller Hook
-- ============================================================================

-- Hook PlayerController:OnControl for button combination handling
AddComponentPostInit("playercontroller", function(inst)
    Helpers.DebugPrint("Initializing Enhanced Controller")

    -- Log task configuration
    Helpers.DebugPrint("Task Configuration:")
    for task_name, task in pairs(TASKS) do
        Helpers.DebugPrintf("  - %s: %d on_press, %d on_release",
            task_name, #task.on_press, #task.on_release)
    end

    -- Initialize button state for this player
    if inst.inst and inst.inst.GUID then
        ButtonHandler.InitializePlayer(inst.inst)
        ACTIONS.InitEquipmentTracking(inst.inst)
    end

    -- Hook OnControl to handle button combinations
    local OldOnControl = inst.OnControl
    inst.OnControl = function(self, control, down)
        local player = self.inst

        -- Try to handle as button combination
        local handled = ButtonHandler.HandleButtonCombination(
            player,
            control,
            down,
            BUTTON_MAPPINGS,
            TASKS,
            function(p, action_list)
                ActionExecutor.ExecuteTaskActions(p, action_list, ACTIONS)
            end
        )

        -- If handled as combination, block default behavior
        if handled then
            return true
        end

        -- Otherwise, use default behavior
        return OldOnControl(self, control, down)
    end
end)

Helpers.DebugPrint("Enhanced Controller mod loaded successfully")
