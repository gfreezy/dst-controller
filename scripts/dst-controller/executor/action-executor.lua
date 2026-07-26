-- Enhanced Controller - Action Executor Module
-- Handles execution of actions from task definitions

local Helpers = require("dst-controller/utils/helpers")
local unpack_params = unpack or table.unpack

local ActionExecutor = {}
local active_sequences = {}
local cleanup_installed = setmetatable({}, { __mode = "k" })
local next_sequence_id = 0

local FAILURE_MARKER = {}

local function Failure(reason)
    return { _marker = FAILURE_MARKER, reason = reason }
end

local function IsFailure(result)
    return type(result) == "table" and result._marker == FAILURE_MARKER
end

local function GetPlayerKey(player)
    return player and (player.GUID or player) or nil
end

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
-- Returns: delay_time, pending task, or nil.
function ActionExecutor.ExecuteAction(player, action_def, actions)
    if not player then
        Helpers.DebugPrint("No player found")
        return Failure("missing_player")
    end

    -- Parse action definition
    local action_name, params
    if type(action_def) == "string" then
        -- Simple action: "action_name"
        action_name = action_def
        params = {}
    elseif type(action_def) == "table" and type(action_def[1]) == "string" then
        -- Action with parameters: {"action_name", "param1", "param2", ...}
        action_name = action_def[1]
        params = {}
        for i = 2, #action_def do
            table.insert(params, action_def[i])
        end
    else
        Helpers.DebugPrintf("Warning: Invalid action definition type '%s'", type(action_def))
        return Failure("invalid_action_definition")
    end

    -- Special handling for delay action (explicit delay)
    if action_name == "delay" then
        local delay_time = math.max(0, math.min(30, tonumber(params[1]) or 0.1))
        Helpers.DebugPrintf("Delay: %.2f seconds", delay_time)
        return delay_time
    end

    -- Execute action
    local action_func = actions and actions[action_name] or nil
    if type(action_func) == "function" then
        local ok, result = pcall(action_func, player, unpack_params(params))
        if not ok then
            Helpers.DebugPrintf("Action '%s' failed: %s", action_name, tostring(result))
            return Failure("action_error:" .. tostring(action_name))
        end
        if type(result) == "table" and result.pending and result.OnComplete ~= nil then
            return result
        end
        -- Return auto-delay for this action type
        return GetAutoDelay(action_name)
    else
        Helpers.DebugPrintf("Warning: Unknown action '%s'", action_name)
        return Failure("unknown_action:" .. tostring(action_name))
    end

    return nil
end

local function IsSequenceActive(sequence)
    return sequence.status == "pending" and
        active_sequences[sequence.player_key] == sequence
end

local function FinishSequence(sequence, status, reason)
    if sequence.status ~= "pending" then
        return
    end
    sequence.status = status
    sequence.reason = reason
    if active_sequences[sequence.player_key] == sequence then
        active_sequences[sequence.player_key] = nil
    end
end

local function CancelSequence(sequence, reason)
    if sequence == nil or sequence.status ~= "pending" then
        return false
    end

    -- Mark it first: Cancel() implementations are allowed to synchronously fire
    -- completion callbacks, which must see this sequence as inactive.
    sequence.status = "cancelled"
    sequence.reason = reason or "cancelled"
    if active_sequences[sequence.player_key] == sequence then
        active_sequences[sequence.player_key] = nil
    end
    if sequence.scheduled ~= nil and sequence.scheduled.Cancel ~= nil then
        sequence.scheduled:Cancel()
    end
    sequence.scheduled = nil
    if sequence.pending_action ~= nil and sequence.pending_action.Cancel ~= nil then
        pcall(sequence.pending_action.Cancel, sequence.pending_action, sequence.reason)
    end
    sequence.pending_action = nil
    return true
end

function ActionExecutor.Cancel(player, reason)
    return CancelSequence(active_sequences[GetPlayerKey(player)], reason)
end

-- Execute remaining actions after a delay
local function ExecuteRemainingActions(sequence, start_index)
    if not IsSequenceActive(sequence) then
        return
    end

    local player = sequence.player
    local action_list = sequence.action_list
    local actions = sequence.actions
    local i = start_index
    while i <= #action_list do
        if not IsSequenceActive(sequence) or not player:IsValid() then
            FinishSequence(sequence, "interrupted", "invalid_player")
            return
        end

        local action_def = action_list[i]
        local result = ActionExecutor.ExecuteAction(player, action_def, actions)

        -- Check if there are more actions after this one
        local has_more_actions = i < #action_list

        if IsFailure(result) then
            FinishSequence(sequence, "failed", result.reason)
            return
        elseif type(result) == "table" and result.pending and result.OnComplete ~= nil then
            sequence.pending_action = result
            local ok, callback_error = pcall(result.OnComplete, result, function(status, reason)
                if not IsSequenceActive(sequence) then
                    return
                end
                sequence.pending_action = nil
                if status == "success" and player:IsValid() then
                    if has_more_actions then
                        ExecuteRemainingActions(sequence, i + 1)
                    else
                        FinishSequence(sequence, "success")
                    end
                else
                    FinishSequence(sequence, status or "failed", reason)
                end
            end)
            if not ok then
                sequence.pending_action = nil
                Helpers.DebugPrintf("Failed to observe pending action: %s", tostring(callback_error))
                FinishSequence(sequence, "failed", "pending_callback_error")
            end
            return
        elseif type(result) == "number" and result > 0 and has_more_actions then
            -- Schedule remaining actions after delay
            if player:IsValid() then
                local expected_id = sequence.id
                sequence.scheduled = player:DoTaskInTime(result, function()
                    sequence.scheduled = nil
                    if IsSequenceActive(sequence) and sequence.id == expected_id and player:IsValid() then
                        ExecuteRemainingActions(sequence, i + 1)
                    end
                end)
            else
                FinishSequence(sequence, "interrupted", "invalid_player")
            end
            return  -- Exit current execution, will continue after delay
        end

        i = i + 1
    end
    FinishSequence(sequence, "success")
end

-- Execute a list of actions sequentially (with auto-delay support)
-- Auto-delay is automatically added after equipment/item actions
-- Explicit delays can still be specified as {"delay", seconds}
-- Example: {"equip_item", "lighter"}, {"use_item_on_scene", "lighter"}
--          (auto-delay of 0.3s will be added between them)
function ActionExecutor.ExecuteTaskActions(player, action_list, actions)
    if player == nil or type(action_list) ~= "table" then
        return nil
    end

    ActionExecutor.Cancel(player, "replaced")
    next_sequence_id = next_sequence_id + 1
    local sequence = {
        id = next_sequence_id,
        player = player,
        player_key = GetPlayerKey(player),
        action_list = action_list,
        actions = actions or {},
        status = "pending",
        reason = nil,
        scheduled = nil,
        pending_action = nil,
    }
    function sequence:Cancel(reason)
        return CancelSequence(self, reason)
    end

    active_sequences[sequence.player_key] = sequence
    if player.ListenForEvent ~= nil and not cleanup_installed[player] then
        cleanup_installed[player] = true
        player:ListenForEvent("onremove", function()
            ActionExecutor.Cancel(player, "player_removed")
            cleanup_installed[player] = nil
        end)
    end

    ExecuteRemainingActions(sequence, 1)
    return sequence
end

function ActionExecutor._ResetForTests()
    for _, sequence in pairs(active_sequences) do
        CancelSequence(sequence, "test_reset")
    end
    active_sequences = {}
    cleanup_installed = setmetatable({}, { __mode = "k" })
end

return ActionExecutor
