-- Enhanced Controller - Global References
-- This module provides centralized access to GLOBAL references for all other modules
-- All GLOBAL references are extracted once here, and other modules can require this file

local G = {}
local initialized = false

-- Initialize G with GLOBAL references
-- This must be called from modmain.lua before any other modules use G
function G.Init(ENV_REF)
    if initialized then
        return -- Already initialized
    end

    local GLOBAL_REF = ENV_REF.GLOBAL

    -- ============================================================================
    -- Control Constants
    -- ============================================================================
    G.CONTROL_CAM_AND_INV_MODIFIER = GLOBAL_REF.CONTROL_CAM_AND_INV_MODIFIER
    G.CONTROL_CHARACTER_COMMAND_WHEEL = GLOBAL_REF.CONTROL_CHARACTER_COMMAND_WHEEL
    G.CONTROL_ACCEPT = GLOBAL_REF.CONTROL_ACCEPT
    G.CONTROL_CONTROLLER_ACTION = GLOBAL_REF.CONTROL_CONTROLLER_ACTION
    G.CONTROL_CANCEL = GLOBAL_REF.CONTROL_CANCEL
    G.CONTROL_CONTROLLER_ALTACTION = GLOBAL_REF.CONTROL_CONTROLLER_ALTACTION
    G.CONTROL_CONTROLLER_ATTACK = GLOBAL_REF.CONTROL_CONTROLLER_ATTACK
    G.CONTROL_PUTSTACK = GLOBAL_REF.CONTROL_PUTSTACK
    G.CONTROL_MENU_MISC_1 = GLOBAL_REF.CONTROL_MENU_MISC_1
    G.CONTROL_MENU_MISC_2 = GLOBAL_REF.CONTROL_MENU_MISC_2
    G.CONTROL_INSPECT = GLOBAL_REF.CONTROL_INSPECT
    G.CONTROL_MAP_ZOOM_IN = GLOBAL_REF.CONTROL_MAP_ZOOM_IN
    G.CONTROL_OPEN_CRAFTING = GLOBAL_REF.CONTROL_OPEN_CRAFTING
    G.CONTROL_MENU_L2 = GLOBAL_REF.CONTROL_MENU_L2
    G.CONTROL_OPEN_INVENTORY = GLOBAL_REF.CONTROL_OPEN_INVENTORY
    G.CONTROL_MAP_ZOOM_OUT = GLOBAL_REF.CONTROL_MAP_ZOOM_OUT
    G.CONTROL_MENU_R2 = GLOBAL_REF.CONTROL_MENU_R2

    -- ============================================================================
    -- Game API Functions
    -- ============================================================================
    G.AddComponentPostInit = ENV_REF.AddComponentPostInit
    G.AddClassPostConstruct = ENV_REF.AddClassPostConstruct
    G.TheInput = GLOBAL_REF.TheInput
    G.TheSim = GLOBAL_REF.TheSim

    -- ============================================================================
    -- Equipment Slots
    -- ============================================================================
    G.EQUIPSLOTS = GLOBAL_REF.EQUIPSLOTS

    -- ============================================================================
    -- Actions
    -- ============================================================================
    G.ACTIONS = GLOBAL_REF.ACTIONS
    G.BufferedAction = GLOBAL_REF.BufferedAction

    -- ============================================================================
    -- Helper Functions
    -- ============================================================================
    G.FunctionOrValue = GLOBAL_REF.FunctionOrValue
    G.CanEntitySeeTarget = GLOBAL_REF.CanEntitySeeTarget
    G.CanEntitySeePoint = GLOBAL_REF.CanEntitySeePoint
    G.FindEntity = GLOBAL_REF.FindEntity
    G.IsEntityDead = GLOBAL_REF.IsEntityDead
    G.GetPortalRez = GLOBAL_REF.GetPortalRez
    G.anglediff = GLOBAL_REF.anglediff

    -- ============================================================================
    -- Constants
    -- ============================================================================
    G.TUNING = GLOBAL_REF.TUNING
    G.DEGREES = GLOBAL_REF.DEGREES

    -- ============================================================================
    -- Math/Utility Types
    -- ============================================================================
    G.Vector3 = GLOBAL_REF.Vector3

    -- ============================================================================
    -- Button Mappings
    -- ============================================================================
    -- Button mapping table - each logical button can map to multiple physical controls
    G.BUTTON_MAPPINGS = {
        LB = { G.CONTROL_CAM_AND_INV_MODIFIER },
        RB = { G.CONTROL_CHARACTER_COMMAND_WHEEL },
        A = { G.CONTROL_ACCEPT, G.CONTROL_CONTROLLER_ACTION },
        B = { G.CONTROL_CANCEL, G.CONTROL_CONTROLLER_ALTACTION },
        X = { G.CONTROL_CONTROLLER_ATTACK, G.CONTROL_PUTSTACK, G.CONTROL_MENU_MISC_1 },
        Y = { G.CONTROL_MENU_MISC_2, G.CONTROL_INSPECT },
        LT = { G.CONTROL_OPEN_CRAFTING, G.CONTROL_MAP_ZOOM_IN, G.CONTROL_MENU_L2 },
        RT = { G.CONTROL_OPEN_INVENTORY, G.CONTROL_MAP_ZOOM_OUT, G.CONTROL_MENU_R2 },
    }

    initialized = true
end

return G
