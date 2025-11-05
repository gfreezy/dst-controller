-- Enhanced Controller - Button Handler Module
-- Handles button detection, combination checking, and state management

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local ButtonHandler = {}

-- Button combination configuration
-- Maps modifier buttons to face button combinations
local BUTTON_COMBINATIONS = {
    LB = { A = "LB_A", B = "LB_B", X = "LB_X", Y = "LB_Y", LT = "LB_LT", RT = "LB_RT" },
    RB = { A = "RB_A", B = "RB_B", X = "RB_X", Y = "RB_Y", LT = "RB_LT", RT = "RB_RT" },
}

-- Button state tracking per player
-- Structure: [player_guid][modifier][face_button] = { pressed = bool }
local button_states = {}

-- Initialize button handler for a player
function ButtonHandler.InitializePlayer(player)
    local guid = player.GUID
    if not button_states[guid] then
        button_states[guid] = {}
        for modifier_name, _ in pairs(BUTTON_COMBINATIONS) do
            button_states[guid][modifier_name] = {
                A = { pressed = false },
                B = { pressed = false },
                X = { pressed = false },
                Y = { pressed = false },
                LT = { pressed = false },
                RT = { pressed = false },
            }
        end
        Helpers.DebugPrint("Initialized button states for player " .. guid)
    end
end

-- Check if a physical control matches a logical button
function ButtonHandler.IsButton(control, button_name)
    local mappings = G.BUTTON_MAPPINGS[button_name]
    if not mappings then return false end

    for _, mapped_control in ipairs(mappings) do
        if control == mapped_control then
            return true
        end
    end

    return false
end

-- Get logical button name from a physical control
function ButtonHandler.GetLogicalButtonName(control)
    for button_name, mappings in pairs(G.BUTTON_MAPPINGS) do
        for _, mapped_control in ipairs(mappings) do
            if control == mapped_control then
                return button_name
            end
        end
    end
    return nil
end

-- Get all currently pressed logical buttons
function ButtonHandler.GetPressedControls()
    local pressed = {}
    for button_name, _ in pairs(G.BUTTON_MAPPINGS) do
        if Helpers.IsButtonPressed(button_name) then
            table.insert(pressed, button_name)
        end
    end
    return pressed
end

-- Get the action list for a button combination (internal helper)
-- Returns the action list and task info if the control is part of a button combination
-- @param control: the control input
-- @param down: button state (true=press, false=release)
-- @return actions, modifier_name, face_button (all nil if not a combination)
local function GetButtonCombinationActions(control, down)
    -- 检测是否在虚拟光标模式
    local is_virtual_cursor = VirtualCursor.IsCursorModeActive()

    -- 根据模式选择对应的配置
    local tasks = ConfigManager.GetRuntimeTasks(is_virtual_cursor)

    -- Check if this is a modifier button (LB or RB)
    for modifier_name, face_buttons in pairs(BUTTON_COMBINATIONS) do
        if Helpers.IsButtonPressed(modifier_name) then
            -- Modifier is pressed, check if face button event
            for face_button, task_name in pairs(face_buttons) do
                if ButtonHandler.IsButton(control, face_button) then
                    -- This is a button combination event
                    local task = tasks[task_name]
                    if task then
                        -- Return the appropriate action list based on down state
                        local actions = down and task.on_press or task.on_release
                        local need_handle = task.on_press or task.on_release
                        return actions, need_handle, modifier_name, face_button
                    end
                    return nil, false, nil, nil  -- No task or no actions
                end
            end
        end
    end

    return nil, false, nil, nil  -- Not a button combination
end

-- Get the action list for a button combination
-- Returns the action list if the control is part of a button combination that has actions configured
-- @param control: the control input
-- @param down: button state (true=press, false=release)
-- @return actions table or nil
function ButtonHandler.GetButtonCombinationActions(control, down)
    local actions, need_handle = GetButtonCombinationActions(control, down)
    return actions, need_handle
end

-- Handle button combination events
-- Returns true if a combination was handled, false otherwise
function ButtonHandler.HandleButtonCombination(player, control, down, execute_callback)
    local guid = player.GUID

    -- Initialize if needed
    if not button_states[guid] then
        ButtonHandler.InitializePlayer(player)
    end

    -- Get the actions for this button combination
    local actions, need_handle, modifier_name, face_button = GetButtonCombinationActions(control, down)

    if not need_handle then
        return false  -- Not a button combination or no actions
    end

    -- Handle button state to prevent repeated execution
    local state = button_states[guid][modifier_name][face_button]

    print("[ButtonHandler] Handling button combination: " .. modifier_name .. " + " .. face_button, "down: " .. tostring(down), "state: " .. table.inspect(state))

    if down then
        -- Button press event
        if not state.pressed then
            Helpers.DebugPrintf("%s + %s pressed -> executing %d actions",
                modifier_name, face_button, #actions)
            execute_callback(player, actions)
            state.pressed = true
        end
    else
        -- Button release event
        if state.pressed then
            Helpers.DebugPrintf("%s + %s released -> executing %d actions",
                modifier_name, face_button, #actions)
            execute_callback(player, actions)
            state.pressed = false
        end
    end

    return true  -- Combination handled
end

return ButtonHandler
