-- Enhanced Controller - Action Executor Module
-- Handles execution of actions from task definitions

local Helpers = require("dst-controller/utils/helpers")

local ActionExecutor = {}

-- ============================================================================
-- Global Auto-Delay Configuration
-- ============================================================================
-- Actions that change equipment or game state need a delay before the next action
-- to allow the server to process and sync the state back to the client.
local AUTO_DELAY_ACTIONS = {
    -- Equipment actions that change what's in hand/equipped
    equip_item = 0.3,
    unequip_item = 0.3,
    cycle_hand = 0.3,
    cycle_hand_prev = 0.3,
    cycle_head = 0.3,
    cycle_head_prev = 0.3,
    cycle_body = 0.3,
    cycle_body_prev = 0.3,
    swap_hand_last = 0.3,
    swap_head_last = 0.3,
    swap_body_last = 0.3,
    restore_hand_item = 0.3,
    restore_head_item = 0.3,
    restore_body_item = 0.3,
    -- Item usage actions
    use_item_on_self = 0.3,
    use_item_on_scene = 0.3,
    use_active_item_on_self = 0.3,
    use_active_item_on_scene = 0.3,
    use_equip = 0.3,
}

-- Global delay multiplier (can be adjusted)
ActionExecutor.DelayMultiplier = 1.0

-- Get the auto-delay for an action (0 if no delay needed)
local function GetAutoDelay(action_name)
    local base_delay = AUTO_DELAY_ACTIONS[action_name]
    if base_delay then
        return base_delay * ActionExecutor.DelayMultiplier
    end
    return 0
end

-- Execute a single action
-- action_def can be:
--   - A string: "action_name" (simple action)
--   - A table: {"action_name", "param1", "param2", ...} (action with parameters)
-- Returns: delay_time (auto-delay or explicit delay), nil if no delay
function ActionExecutor.ExecuteAction(player, action_def, actions)
    if not player then
        Helpers.DebugPrint("No player found")
        return nil
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
        Helpers.DebugPrintf("Warning: Invalid action definition type '%s'", type(action_def))
        return nil
    end

    -- Special handling for delay action (explicit delay)
    if action_name == "delay" then
        local delay_time = tonumber(params[1]) or 0.1
        Helpers.DebugPrintf("Delay: %.2f seconds", delay_time)
        return delay_time
    end

    -- Execute action
    local action_func = actions[action_name]
    if action_func then
        action_func(player, unpack(params))
        -- Return auto-delay for this action type
        return GetAutoDelay(action_name)
    else
        Helpers.DebugPrintf("Warning: Unknown action '%s'", action_name)
    end

    return nil
end

-- Execute remaining actions after a delay
local function ExecuteRemainingActions(player, action_list, actions, start_index)
    local i = start_index
    while i <= #action_list do
        local action_def = action_list[i]
        local delay_time = ActionExecutor.ExecuteAction(player, action_def, actions)

        -- Check if there are more actions after this one
        local has_more_actions = i < #action_list

        if delay_time and delay_time > 0 and has_more_actions then
            -- Schedule remaining actions after delay
            if player:IsValid() then
                player:DoTaskInTime(delay_time, function()
                    if player:IsValid() then
                        ExecuteRemainingActions(player, action_list, actions, i + 1)
                    end
                end)
            end
            return  -- Exit current execution, will continue after delay
        end

        i = i + 1
    end
end

-- Execute a list of actions sequentially (with auto-delay support)
-- Auto-delay is automatically added after equipment/item actions
-- Explicit delays can still be specified as {"delay", seconds}
-- Example: {"equip_item", "lighter"}, {"use_item_on_scene", "lighter"}
--          (auto-delay of 0.3s will be added between them)
function ActionExecutor.ExecuteTaskActions(player, action_list, actions)
    ExecuteRemainingActions(player, action_list, actions, 1)
end

return ActionExecutor
