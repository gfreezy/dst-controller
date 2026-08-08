-- Enhanced Controller - Button Handler Module
-- Handles button detection, combination checking, and state management

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local ButtonCombos = require("dst-controller/config/button-combos")

local ButtonHandler = {}

-- Button combination configuration
-- Maps modifier buttons to face button combinations
local BUTTON_COMBINATIONS = ButtonCombos.GetByModifier()
local MODIFIER_ORDER = { "LB", "RB" }

-- Button state tracking per player
-- Structure: [player_guid][modifier][face_button] =
--   { pressed = bool, release_actions = table|nil }
local button_states = {}
local modifier_states = {}

local function NewButtonState()
    return { pressed = false, release_actions = nil }
end

local function TaskHasActions(task)
    return task ~= nil and
        ((type(task.on_press) == "table" and #task.on_press > 0) or
         (type(task.on_release) == "table" and #task.on_release > 0))
end

-- Initialize button handler for a player
function ButtonHandler.InitializePlayer(player)
    local guid = player.GUID
    if not button_states[guid] then
        button_states[guid] = {}
        for _, modifier_name in ipairs(MODIFIER_ORDER) do
            button_states[guid][modifier_name] = {}
            for face_button in pairs(BUTTON_COMBINATIONS[modifier_name]) do
                button_states[guid][modifier_name][face_button] = NewButtonState()
            end
        end
        if player.ListenForEvent ~= nil then
            player:ListenForEvent("onremove", function()
                ButtonHandler.RemovePlayer(player)
            end)
        end
        Helpers.DebugPrint("Initialized button states for player " .. guid)
    end
    modifier_states[guid] = modifier_states[guid] or { LB = false, RB = false }
end

function ButtonHandler.RemovePlayer(player_or_guid)
    local guid = type(player_or_guid) == "table" and player_or_guid.GUID or player_or_guid
    if guid ~= nil then
        button_states[guid] = nil
        modifier_states[guid] = nil
    end
end

-- PlayerHud sees crafting/inventory triggers before PlayerController. Remember
-- shoulder transitions there so trigger combo detection does not depend only
-- on the active control scheme's semantic control state.
function ButtonHandler.ObserveModifierControl(player, control, down)
    if player == nil or player.GUID == nil then
        return false
    end
    ButtonHandler.InitializePlayer(player)
    for _, modifier_name in ipairs(MODIFIER_ORDER) do
        if ButtonHandler.IsButton(control, modifier_name) then
            modifier_states[player.GUID][modifier_name] = down == true
            return true
        end
    end
    return false
end

-- Modal screens can consume the release event that normally clears a combo.
-- Clear only transient pressed state while keeping the player lifecycle entry.
function ButtonHandler.ClearPressedStates(player_or_guid)
    local guid = type(player_or_guid) == "table" and
        player_or_guid.GUID or player_or_guid
    local player_states = guid ~= nil and button_states[guid] or nil
    if player_states == nil then
        return
    end
    for _, face_buttons in pairs(player_states) do
        for _, state in pairs(face_buttons) do
            state.pressed = false
            state.release_actions = nil
        end
    end
    local modifiers = modifier_states[guid]
    if modifiers ~= nil then
        modifiers.LB = false
        modifiers.RB = false
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
local function IsModifierPressed(player, modifier_name)
    if Helpers.IsButtonPressed(modifier_name) then
        return true
    end
    local guid = player and player.GUID or nil
    return guid ~= nil and modifier_states[guid] ~= nil and
        modifier_states[guid][modifier_name] == true
end

local function GetButtonCombinationActions(control, down, player)
    -- 检测是否在虚拟光标模式
    local is_virtual_cursor = VirtualCursor.IsCursorModeActive()

    -- 根据模式选择对应的配置
    local tasks = ConfigManager.GetRuntimeTasks(is_virtual_cursor)

    -- Check if this is a modifier button (LB or RB)
    for _, modifier_name in ipairs(MODIFIER_ORDER) do
        local face_buttons = BUTTON_COMBINATIONS[modifier_name]
        if IsModifierPressed(player, modifier_name) then
            -- Modifier is pressed, check if face button event
            for face_button, task_name in pairs(face_buttons) do
                if ButtonHandler.IsButton(control, face_button) then
                    -- This is a button combination event
                    local available = ButtonCombos.IsAvailableInMode(
                        task_name,
                        is_virtual_cursor and "virtual_cursor" or "tasks"
                    )
                    local task = available and tasks[task_name] or nil
                    if TaskHasActions(task) then
                        -- Return the appropriate action list based on down state
                        local actions = down and task.on_press or task.on_release
                        return actions or {}, true, modifier_name, face_button, task
                    end
                    -- This shoulder has no configured task. If both shoulders
                    -- are held, allow the other shoulder's configured combo to
                    -- claim the same physical button before falling through.
                    break
                end
            end
        end
    end

    return nil, false, nil, nil  -- Not a button combination
end

local function GetCapturedCombination(guid, control)
    local player_states = button_states[guid]
    if player_states == nil then
        return nil
    end

    for _, modifier_name in ipairs(MODIFIER_ORDER) do
        local face_buttons = player_states[modifier_name]
        for face_button, state in pairs(face_buttons) do
            if state.pressed and ButtonHandler.IsButton(control, face_button) then
                return state.release_actions or {}, true, modifier_name, face_button
            end
        end
    end
end

-- Get the action list for a button combination
-- Returns the action list if the control is part of a button combination that has actions configured
-- @param control: the control input
-- @param down: button state (true=press, false=release)
-- @return actions table or nil
function ButtonHandler.GetButtonCombinationActions(control, down, player)
    local actions, need_handle = GetButtonCombinationActions(control, down, player)
    return actions, need_handle
end


-- PlayerHud uses this before its native crafting/inventory handling. Captured
-- releases are included so either shoulder/trigger release order is safe.
function ButtonHandler.ShouldHandleControl(player, control, down)
    if not down and player ~= nil and player.GUID ~= nil then
        local _, captured = GetCapturedCombination(player.GUID, control)
        if captured then
            return true
        end
    end
    local _, need_handle = GetButtonCombinationActions(control, down, player)
    return need_handle == true
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
    local actions, need_handle, modifier_name, face_button, task
    if not down then
        actions, need_handle, modifier_name, face_button = GetCapturedCombination(guid, control)
    end
    if not need_handle then
        actions, need_handle, modifier_name, face_button, task =
            GetButtonCombinationActions(control, down, player)
    end

    if not need_handle then
        return false  -- Not a button combination or no actions
    end

    -- Handle button state to prevent repeated execution
    local state = button_states[guid][modifier_name][face_button]

    if down then
        -- Button press event
        if not state.pressed then
            Helpers.DebugPrintf("%s + %s pressed -> executing %d actions",
                modifier_name, face_button, #actions)
            if #actions > 0 then
                execute_callback(player, actions)
            end
            state.pressed = true
            state.release_actions = task and task.on_release or {}
        end
    else
        -- Button release event
        if state.pressed then
            Helpers.DebugPrintf("%s + %s released -> executing %d actions",
                modifier_name, face_button, #actions)
            if #actions > 0 then
                execute_callback(player, actions)
            end
            state.pressed = false
            state.release_actions = nil
        end
    end

    return true  -- Combination handled
end


-- Test support: clear module-owned state without touching game input state.
function ButtonHandler._ResetForTests()
    button_states = {}
    modifier_states = {}
end

return ButtonHandler
