-- Enhanced Controller Mod - Main Implementation
-- This mod enhances gamepad/controller functionality with custom button combinations
-- and advanced camera controls

-- Access global environment
for _, v in ipairs({ "_G", "setmetatable", "rawget" }) do
	env[v] = GLOBAL[v]
end

setmetatable(env,
{
	__index = function(table, key) return rawget(_G, key) end
})

-- ============================================================================
-- Configuration
-- ============================================================================

-- Load action and task definitions from external files
local ACTIONS = require("ec-actions")
local TASKS = require("ec-tasks")

-- ============================================================================
-- Controller Button Mapping
-- ============================================================================

-- Button mapping table - each logical button can map to multiple physical controls
-- This allows supporting different control schemes and configurations
local BUTTON_MAPPINGS = {
    LB = {
        CONTROL_CAM_AND_INV_MODIFIER,
    },
    RB = {
        CONTROL_CHARACTER_COMMAND_WHEEL,
    },
    A = {
        CONTROL_ACCEPT,
        CONTROL_CONTROLLER_ACTION,
    },
    B = {
        CONTROL_CANCEL,
        CONTROL_CONTROLLER_ALTACTION,
    },
    X = {
        CONTROL_CONTROLLER_ATTACK,
        CONTROL_PUTSTACK,
        CONTROL_MENU_MISC_1

    },
    Y = {
        CONTROL_INSPECT,
        CONTROL_TARGET_CYCLE,
        CONTROL_USE_ITEM_ON_ITEM,
        CONTROL_MENU_MISC_2,
        CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID,
    },
    LT = {
        CONTROL_OPEN_CRAFTING,
        CONTROL_MENU_L2,
        CONTROL_MAP_ZOOM_IN,

    },
    RT = {
        CONTROL_OPEN_INVENTORY,
        CONTROL_MAP_ZOOM_OUT,
        CONTROL_MENU_R2,
    },
}

-- ============================================================================
-- Helper Functions for Button Mapping
-- ============================================================================

-- Check if a physical control matches a logical button
local function IsButton(control, button_name)
    local mappings = BUTTON_MAPPINGS[button_name]
    if not mappings then return false end

    for _, mapped_control in ipairs(mappings) do
        if control == mapped_control then
            return true
        end
    end

    return false
end

-- Check if a logical button is currently pressed (any of its physical controls)
local function IsButtonPressed(button_name)
    local mappings = BUTTON_MAPPINGS[button_name]
    if not mappings then return false end

    for _, control in ipairs(mappings) do
        if TheInput:IsControlPressed(control) then
            return true
        end
    end

    return false
end

-- Get logical button name from a physical control
local function GetLogicalButtonName(control)
    for button_name, mappings in pairs(BUTTON_MAPPINGS) do
        for _, mapped_control in ipairs(mappings) do
            if control == mapped_control then
                return button_name
            end
        end
    end
    return nil
end

-- ============================================================================
-- Display Helper Functions
-- ============================================================================

-- Get button name for display
local function GetButtonName(control)
    local logical_name = GetLogicalButtonName(control)
    if logical_name then
        return logical_name
    end
    return string.format("Control_%d", control)
end

-- Get all currently pressed logical buttons
local function GetPressedControls()
    local pressed = {}
    for button_name, _ in pairs(BUTTON_MAPPINGS) do
        if IsButtonPressed(button_name) then
            table.insert(pressed, button_name)
        end
    end
    return pressed
end

-- ============================================================================
-- Action Execution
-- ============================================================================

-- Execute a single action
-- action_def can be:
--   - A string: "action_name" (simple action)
--   - A table: {"action_name", "param1", "param2", ...} (action with parameters)
local function ExecuteAction(player, action_def)
    if not player then
        print("[Enhanced Controller] No player found")
        return
    end

    -- Parse action definition
    local action_name, params
    if type(action_def) == "string" then
        -- Simple action: "action_name"
        action_name = action_def
        params = {}
    elseif type(action_def) == "table" then
        -- Action with parameters: {"action_name", "param1", "param2", ...}
        action_name = action_def[1]
        params = {}
        for i = 2, #action_def do
            table.insert(params, action_def[i])
        end
    else
        print(string.format("[Enhanced Controller] Warning: Invalid action definition type '%s'", type(action_def)))
        return
    end

    -- Execute action
    local action_func = ACTIONS[action_name]
    if action_func then
        action_func(player, unpack(params))
    else
        print(string.format("[Enhanced Controller] Warning: Unknown action '%s'", action_name))
    end
end

-- ============================================================================
-- Controller Input Handler
-- ============================================================================

-- Button combination to task mapping
-- Maps modifier button + face button to their task name in tasks.lua
local BUTTON_COMBINATIONS = {
    LB = {
        A = "LB_A",
        B = "LB_B",
        X = "LB_X",
        Y = "LB_Y",
    },
    RB = {
        A = "RB_A",
        B = "RB_B",
        X = "RB_X",
        Y = "RB_Y",
    },
}

-- State tracking for button combinations
-- Format: [modifier_name][face_button] = { pressed = bool }
local button_states = {
    LB = {},
    RB = {},
}

-- Execute actions from a task
local function ExecuteTaskActions(player, actions)
    if not actions or #actions == 0 then
        return
    end

    for _, action_name in ipairs(actions) do
        ExecuteAction(player, action_name)
    end
end

-- Check if a button combination should be handled
-- Returns true if the combination was handled (should block default behavior)
local function HandleButtonCombination(player, control, down)
    -- Check each modifier button (LB, RB)
    for modifier_name, face_buttons in pairs(BUTTON_COMBINATIONS) do
        if IsButtonPressed(modifier_name) then
            -- Check each face button (A, B, X, Y)
            for face_button, task_name in pairs(face_buttons) do
                if IsButton(control, face_button) then
                    -- Get task definition
                    local task = TASKS[task_name]
                    if not task then
                        print(string.format("[Enhanced Controller] Warning: Task '%s' not found", task_name))
                        return true
                    end

                    print(string.format("[Enhanced Controller] Detected combination: %s + %s (%s)",
                        modifier_name, face_button, down and "press" or "release"))

                    -- Initialize state if not exists
                    if not button_states[modifier_name][face_button] then
                        button_states[modifier_name][face_button] = { pressed = false }
                    end

                    local state = button_states[modifier_name][face_button]

                    if down then
                        -- Button press event
                        if not state.pressed then
                            print(string.format("[Enhanced Controller] %s + %s pressed -> executing %d actions",
                                modifier_name, face_button, #task.on_press))
                            ExecuteTaskActions(player, task.on_press)
                            state.pressed = true
                        end
                    else
                        -- Button release event
                        if state.pressed then
                            print(string.format("[Enhanced Controller] %s + %s released -> executing %d actions",
                                modifier_name, face_button, #task.on_release))
                            ExecuteTaskActions(player, task.on_release)
                            state.pressed = false
                        end
                    end

                    return true
                end
            end
        end
    end

    return false
end


-- ============================================================================
-- HUD Initialization - Hook earlier to prevent InspectSelf
-- ============================================================================

-- Hook PlayerHud:OnControl to block button combinations at HUD level
-- This is necessary because HUD's OnControl runs before PlayerController's
AddClassPostConstruct("screens/playerhud", function(self)
    local OldHudOnControl = self.OnControl

    self.OnControl = function(hud_self, control, down)
        -- If LB or RB is pressed, block all controls to prevent default HUD actions
        if IsButtonPressed("LB") or IsButtonPressed("RB") then
            return false
        end

        return OldHudOnControl(hud_self, control, down)
    end
end)

-- ============================================================================
-- Player Initialization
-- ============================================================================

-- Initialize mod for each player instance
AddComponentPostInit("playercontroller", function(inst)
    print("[Enhanced Controller] Initializing for player")
    print("[Enhanced Controller] Task Configuration:")
    for modifier_name, face_buttons in pairs(BUTTON_COMBINATIONS) do
        for face_button, task_name in pairs(face_buttons) do
            local task = TASKS[task_name]
            if task then
                print(string.format("  - %s + %s: %d on_press, %d on_release",
                    modifier_name, face_button, #task.on_press, #task.on_release))
            end
        end
    end

    local playercontroller = inst
    if not playercontroller then
        print("[Enhanced Controller] ERROR: PlayerController component not found!")
        return
    end

    -- Initialize equipment tracking for this player
    -- This sets up event listeners for equip/unequip events
    if ACTIONS.InitEquipmentTracking then
        ACTIONS.InitEquipmentTracking(playercontroller.inst)
        print("[Enhanced Controller] Equipment tracking initialized")
    end

    local OldOnControl = playercontroller.OnControl

    playercontroller.OnControl = function(self, control, down)
        -- Debug output: show current control and all pressed controls
        local pressed = GetPressedControls()
        local pressed_str = #pressed > 0 and table.concat(pressed, " + ") or "None"
        print(string.format("[Enhanced Controller] %s %s | All pressed: [%s]",
            GetButtonName(control), down and "pressed" or "released", pressed_str))

        -- Block LB/RB press to prevent default behavior
        if IsButton(control, "LB") or IsButton(control, "RB") then
            if down then
                -- print(string.format("[Enhanced Controller] Blocking %s press", GetButtonName(control)))
                return true
            else
                -- print(string.format("[Enhanced Controller] %s released", GetButtonName(control)))
                return false
            end
        end

        -- Check for button combinations (both press and release)
        local lb_pressed = IsButtonPressed("LB")
        local rb_pressed = IsButtonPressed("RB")

        -- If LB/RB is pressed, or if this is a release of a face button
        -- (for ON_RELEASE mode), try to handle combination
        if (lb_pressed or rb_pressed) then
            if HandleButtonCombination(self.inst, control, down) then
                return true
            end
        end

        -- Call original OnControl for all other inputs
        return OldOnControl(self, control, down)
    end

    print("[Enhanced Controller] PlayerController:OnControl hooked successfully")
    print("[Enhanced Controller] Player initialization complete")
end)

print("[Enhanced Controller] ============================================")
print("[Enhanced Controller] Mod loaded successfully")
print("[Enhanced Controller] Button Mappings:")
print("  - LB: CONTROL_CAM_AND_INV_MODIFIER (90), CONTROL_SCROLLBACK (31)")
print("  - RB: CONTROL_SCROLLFWD (32), CONTROL_CHARACTER_COMMAND_WHEEL (91)")
print("  - A: CONTROL_ACCEPT (29)")
print("  - B: CONTROL_CANCEL (30)")
print("  - X: CONTROL_CONTROLLER_ATTACK (56)")
print("  - Y: CONTROL_INVENTORY_EXAMINE (51)")
print("  - LT: CONTROL_OPEN_CRAFTING (46)")
print("  - RT: CONTROL_ATTACK (24), CONTROL_OPEN_INVENTORY (45)")
print("[Enhanced Controller] ============================================")
