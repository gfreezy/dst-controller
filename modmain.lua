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

-- Get button combination action configurations
local LB_A_ACTION = GetModConfigData("lb_a_action") or "none"
local LB_B_ACTION = GetModConfigData("lb_b_action") or "none"
local LB_X_ACTION = GetModConfigData("lb_x_action") or "none"
local LB_Y_ACTION = GetModConfigData("lb_y_action") or "none"

local RB_A_ACTION = GetModConfigData("rb_a_action") or "none"
local RB_B_ACTION = GetModConfigData("rb_b_action") or "none"
local RB_X_ACTION = GetModConfigData("rb_x_action") or "none"
local RB_Y_ACTION = GetModConfigData("rb_y_action") or "none"

-- ============================================================================
-- Controller Button Mapping
-- ============================================================================

-- Button mapping table - each logical button can map to multiple physical controls
-- This allows supporting different control schemes and configurations
local BUTTON_MAPPINGS = {
    LB = {
        GLOBAL.CONTROL_CAM_AND_INV_MODIFIER,
    },
    RB = {
        GLOBAL.CONTROL_CHARACTER_COMMAND_WHEEL,
    },
    A = {
        GLOBAL.CONTROL_ACCEPT,
        GLOBAL.CONTROL_CONTROLLER_ACTION,
    },
    B = {
        GLOBAL.CONTROL_CANCEL,
        GLOBAL.CONTROL_CONTROLLER_ALTACTION,
    },
    X = {
        GLOBAL.CONTROL_CONTROLLER_ATTACK,
        GLOBAL.CONTROL_PUTSTACK,
        GLOBAL.CONTROL_MENU_MISC_1

    },
    Y = {
        GLOBAL.CONTROL_INSPECT,
        GLOBAL.CONTROL_TARGET_CYCLE,
        GLOBAL.CONTROL_USE_ITEM_ON_ITEM,
        GLOBAL.CONTROL_MENU_MISC_2,
        GLOBAL.CONTROL_AXISALIGNEDPLACEMENT_CYCLEGRID,
    },
    LT = {
        GLOBAL.CONTROL_OPEN_CRAFTING,
        GLOBAL.CONTROL_MENU_L2,
        GLOBAL.CONTROL_MAP_ZOOM_IN,

    },
    RT = {
        GLOBAL.CONTROL_OPEN_INVENTORY,
        GLOBAL.CONTROL_MAP_ZOOM_OUT,
        GLOBAL.CONTROL_MENU_R2,
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
        if GLOBAL.TheInput:IsControlPressed(control) then
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

-- Execute custom actions based on action type
local function ExecuteCustomAction(player, action_type)
    print(string.format("[Enhanced Controller] Executing action: %s", action_type))

    if action_type == "none" then
        return
    end

    if not player then
        print("[Enhanced Controller] No player found")
        return
    end

    -- Attack action
    if action_type == "attack" then
        local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()
        if target and player.components.combat and player.components.combat:CanTarget(target) then
            player.components.combat:DoAttack(target)
            print("[Enhanced Controller] Executing attack action")
        end

    -- Examine action
    elseif action_type == "examine" then
        local target = GLOBAL.TheInput:GetWorldEntityUnderMouse()
        if target then
            local action = GLOBAL.BufferedAction(player, target, GLOBAL.ACTIONS.LOOKAT)
            if player.components.playercontroller then
                player.components.playercontroller:DoAction(action)
                print("[Enhanced Controller] Executing examine action")
            end
        end

    -- Auto-equip action
    elseif action_type == "equip" then
        if player.components.inventory then
            local active_item = player.components.inventory:GetActiveItem()
            if active_item and active_item.components.equippable then
                player.components.inventory:Equip(active_item)
                print("[Enhanced Controller] Executing equip action")
            end
        end
    end
end

-- ============================================================================
-- Controller Input Handler
-- ============================================================================

-- Action trigger modes
local TRIGGER_MODE = {
    ONCE = "once",        -- Trigger only once per press, ignore subsequent events until release
    REPEAT = "repeat",    -- Trigger every time the system sends the event (throttling according to interval or no interval)
    RELEASE = "release",  -- Trigger only on button release
}

-- Button combination configuration table
-- Maps modifier button + face button to their configured actions and trigger modes
-- Each entry: { action = "action_name", mode = TRIGGER_MODE.XXX, interval = seconds }
local BUTTON_COMBINATIONS = {
    LB = {
        -- ON_PRESS_ONCE: Press once to trigger, won't repeat while held
        A = { action = LB_A_ACTION, mode = TRIGGER_MODE.ON_PRESS_ONCE},

        -- ON_PRESS_REPEAT: Triggers on press, then repeats every 'interval' seconds while held
        B = { action = LB_B_ACTION, mode = TRIGGER_MODE.ON_PRESS_REPEAT},

        -- ON_RELEASE: Only triggers when button is released
        X = { action = LB_X_ACTION, mode = TRIGGER_MODE.ON_RELEASE },

        -- ON_PRESS_ONCE: Single trigger per press
        Y = { action = LB_Y_ACTION, mode = TRIGGER_MODE.ON_PRESS_ONCE },
    },
    RB = {
        -- ON_PRESS_REPEAT: Fast repeat for rapid actions
        A = { action = RB_A_ACTION, mode = TRIGGER_MODE.ON_PRESS_REPEAT },

        -- ON_PRESS_ONCE: Single trigger
        B = { action = RB_B_ACTION, mode = TRIGGER_MODE.ON_PRESS_ONCE },

        -- ON_PRESS_REPEAT: Medium speed repeat
        X = { action = RB_X_ACTION, mode = TRIGGER_MODE.ON_PRESS_REPEAT},

        -- ON_RELEASE: Trigger on button release
        Y = { action = RB_Y_ACTION, mode = TRIGGER_MODE.ON_RELEASE },
    },
}

-- State tracking for button combinations
-- Format: [modifier_name][face_button] = { pressed = bool }
local button_states = {
    LB = {},
    RB = {},
}

-- Check if a button combination should be handled
-- Returns true if the combination was handled (should block default behavior)
local function HandleButtonCombination(player, control, down)
    -- Check each modifier button (LB, RB)
    for modifier_name, face_buttons in pairs(BUTTON_COMBINATIONS) do
        if IsButtonPressed(modifier_name) then
            -- Check each face button (A, B, X, Y)
            for face_button, config in pairs(face_buttons) do
                if IsButton(control, face_button) then
                    local action = config.action
                    local mode = config.mode

                    -- Initialize state if not exists
                    if not button_states[modifier_name][face_button] then
                        button_states[modifier_name][face_button] = { pressed = false }
                    end

                    local state = button_states[modifier_name][face_button]

                    if down then
                        -- Button press event
                        if mode == TRIGGER_MODE.ON_PRESS_ONCE then
                            -- Only trigger once until released
                            if not state.pressed then
                                print(string.format("[Enhanced Controller] %s + %s -> %s (once)",
                                    modifier_name, face_button, action))
                                if action ~= "none" then
                                    ExecuteCustomAction(player, action)
                                end
                                state.pressed = true
                            end
                        elseif mode == TRIGGER_MODE.ON_PRESS_REPEAT then
                            -- Trigger every time system sends event
                            print(string.format("[Enhanced Controller] %s + %s -> %s (repeat)",
                                modifier_name, face_button, action))
                            if action ~= "none" then
                                ExecuteCustomAction(player, action)
                            end
                            state.pressed = true
                        elseif mode == TRIGGER_MODE.ON_RELEASE then
                            -- Mark as pressed, will trigger on release
                            state.pressed = true
                        end
                    else
                        -- Button release event
                        if mode == TRIGGER_MODE.ON_RELEASE and state.pressed then
                            print(string.format("[Enhanced Controller] %s + %s -> %s (release)",
                                modifier_name, face_button, action))
                            if action ~= "none" then
                                ExecuteCustomAction(player, action)
                            end
                        end
                        state.pressed = false
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
    print("[Enhanced Controller] Configuration:")
    print("  - LB + A:", LB_A_ACTION)
    print("  - LB + B:", LB_B_ACTION)
    print("  - LB + X:", LB_X_ACTION)
    print("  - LB + Y:", LB_Y_ACTION)
    print("  - RB + A:", RB_A_ACTION)
    print("  - RB + B:", RB_B_ACTION)
    print("  - RB + X:", RB_X_ACTION)
    print("  - RB + Y:", RB_Y_ACTION)

    local playercontroller = inst
    if not playercontroller then
        print("[Enhanced Controller] ERROR: PlayerController component not found!")
        return
    end

    local OldOnControl = playercontroller.OnControl

    playercontroller.OnControl = function(self, control, down)
        -- Debug output: show current control and all pressed controls
        -- local pressed = GetPressedControls()
        -- local pressed_str = #pressed > 0 and table.concat(pressed, " + ") or "None"
        -- print(string.format("[Enhanced Controller] %s %s | All pressed: [%s]",
        --     GetButtonName(control), down and "pressed" or "released", pressed_str))

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
