-- Enhanced Controller - Global References
-- This module provides centralized access to GLOBAL and env references for all other modules
-- Uses metatable for dynamic proxy to handle objects created after mod initialization

---@alias EntityScript table DST entity instance
---@alias InputHandler table DST input handler
---@alias Vector3 table DST Vector3 type

---@class GlobalReferences
---@field HINT_UPDATE_INTERVAL number Inventory hint update interval in seconds
---@field BUTTON_MAPPINGS table<string, table<number>> Button mapping table
---
--- Game Objects (from GLOBAL)
---@field ThePlayer EntityScript|nil Current player instance
---@field TheInput InputHandler Input system
---@field TheWorld EntityScript|nil Current world instance
---@field TheSim table Simulation engine
---@field TheFrontEnd table Frontend UI manager
---@field TheCamera table Camera controller
---@field TheNet table Network manager
---
--- Data Tables (from GLOBAL)
---@field TUNING table Game tuning parameters
---@field STRINGS table Game text strings
---@field ACTIONS table Game action definitions
---@field EQUIPSLOTS table Equipment slot constants
---
--- Control Constants (from GLOBAL)
---@field CONTROL_CAM_AND_INV_MODIFIER number
---@field CONTROL_CHARACTER_COMMAND_WHEEL number
---@field CONTROL_ACCEPT number
---@field CONTROL_CONTROLLER_ACTION number
---@field CONTROL_CANCEL number
---@field CONTROL_CONTROLLER_ALTACTION number
---@field CONTROL_CONTROLLER_ATTACK number
---@field CONTROL_PUTSTACK number
---@field CONTROL_MENU_MISC_1 number
---@field CONTROL_MENU_MISC_2 number
---@field CONTROL_INSPECT number
---@field CONTROL_MAP_ZOOM_IN number
---@field CONTROL_OPEN_CRAFTING number
---@field CONTROL_MENU_L2 number
---@field CONTROL_OPEN_INVENTORY number
---@field CONTROL_MAP_ZOOM_OUT number
---@field CONTROL_MENU_R2 number
---@field CONTROL_MOVE_UP number
---@field CONTROL_MOVE_DOWN number
---@field CONTROL_MOVE_LEFT number
---@field CONTROL_MOVE_RIGHT number
---@field CONTROL_USE_ITEM_ON_ITEM number
---@field VIRTUAL_CONTROL_INV_LEFT number
---@field VIRTUAL_CONTROL_INV_RIGHT number
---@field VIRTUAL_CONTROL_INV_UP number
---@field VIRTUAL_CONTROL_INV_DOWN number
---@field VIRTUAL_CONTROL_INV_ACTION_DOWN number
---
--- Math/Utility Types (from GLOBAL)
---@field Vector3 table Vector3 constructor
---@field Point table Point constructor
---@field DEGREES number Degrees to radians multiplier
---
--- Helper Functions (from GLOBAL)
---@field FunctionOrValue fun(fn_or_value: any, ...): any
---@field CanEntitySeeTarget fun(entity: EntityScript, target: EntityScript): boolean
---@field CanEntitySeePoint fun(entity: EntityScript, x: number, y: number, z: number): boolean
---@field FindEntity fun(entity: EntityScript, radius: number, must_have_tags: table|nil, cant_have_tags: table|nil, must_have_one_of_tags: table|nil): EntityScript|nil
---@field IsEntityDead fun(entity: EntityScript): boolean
---@field GetPortalRez fun(): Vector3|nil
---@field anglediff fun(angle1: number, angle2: number): number
---@field GetGameModeProperty fun(property: string): any
---
--- Action System (from GLOBAL)
---@field BufferedAction table BufferedAction constructor
---
--- Mod API Functions (from env)
---@field AddComponentPostInit fun(component: string, fn: function)
---@field AddClassPostConstruct fun(package: string, fn: function)
---@field AddGamePostInit fun(fn: function)
---@field AddSimPostInit fun(fn: function)
---@field AddPrefabPostInit fun(prefab: string, fn: function)
---@field AddPrefabPostInitAny fun(fn: function)
---@field AddPlayerPostInit fun(fn: function)
---@field GetModConfigData fun(option: string, get_local: boolean|nil): any
---@field modimport fun(module: string)
local G = {}

local GLOBAL_REF = nil
local ENV_REF = nil

--- Initialize G with GLOBAL and env references
--- This must be called from modmain.lua before any other modules use G
---@param global_arg table The GLOBAL table from DST
---@param env_arg table The mod environment table
function G.Init(global_arg, env_arg)
    if GLOBAL_REF ~= nil then
        return -- Already initialized
    end

    GLOBAL_REF = global_arg
    ENV_REF = env_arg

    -- Initialize BUTTON_MAPPINGS after GLOBAL_REF is set
    -- This allows us to access CONTROL_* constants through the metatable
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
end

-- Use metatable to dynamically proxy all GLOBAL and env accesses
-- This ensures we always get the latest values, even for objects created after Init()
setmetatable(G, {
    __index = function(t, k)
        -- Priority 1: Check if it's a custom property on G itself
        local custom_value = rawget(t, k)
        if custom_value ~= nil then
            return custom_value
        end

        -- Priority 2: Check env for mod-specific functions (AddComponentPostInit, etc.)
        if ENV_REF and ENV_REF[k] ~= nil then
            return ENV_REF[k]
        end

        -- Priority 3: Check GLOBAL for game objects (ThePlayer, TheInput, etc.)
        if GLOBAL_REF and GLOBAL_REF[k] ~= nil then
            return GLOBAL_REF[k]
        end

        -- Not found
        return nil
    end
})

-- ============================================================================
-- Custom Constants and Configurations
-- ============================================================================

-- Inventory hint update interval in seconds
G.HINT_UPDATE_INTERVAL = 2.0

---@type GlobalReferences
return G
