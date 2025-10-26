-- Enhanced Controller - Action Executor Module
-- Handles execution of actions from task definitions

local Helpers = require("utils/helpers")

local ActionExecutor = {}

-- Execute a single action
-- action_def can be:
--   - A string: "action_name" (simple action)
--   - A table: {"action_name", "param1", "param2", ...} (action with parameters)
function ActionExecutor.ExecuteAction(player, action_def, actions)
    if not player then
        Helpers.DebugPrint("No player found")
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
        Helpers.DebugPrintf("Warning: Invalid action definition type '%s'", type(action_def))
        return
    end

    -- Execute action
    local action_func = actions[action_name]
    if action_func then
        action_func(player, unpack(params))
    else
        Helpers.DebugPrintf("Warning: Unknown action '%s'", action_name)
    end
end

-- Execute a list of actions sequentially
function ActionExecutor.ExecuteTaskActions(player, action_list, actions)
    for _, action_def in ipairs(action_list) do
        ActionExecutor.ExecuteAction(player, action_def, actions)
    end
end

return ActionExecutor
