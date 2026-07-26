package.loaded["dst-controller/utils/helpers"] = {
    DebugPrint = function() end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/executor/action-executor"] = nil

local Executor = require("dst-controller/executor/action-executor")

local player = {
    IsValid = function() return true end,
    DoTaskInTime = function(_, _, fn) fn() end,
}

local pending = { pending = true }
function pending:OnComplete(callback)
    self.callback = callback
end

local calls = {}
local actions = {
    async = function()
        table.insert(calls, "async")
        return pending
    end,
    after = function()
        table.insert(calls, "after")
    end,
}

Executor.ExecuteTaskActions(player, { "async", "after" }, actions)
assert(#calls == 1 and calls[1] == "async", "pending action must pause the task sequence")
pending.callback("success")
assert(#calls == 2 and calls[2] == "after", "successful pending action must resume the sequence")

local interrupted = { pending = true }
function interrupted:OnComplete(callback) self.callback = callback end
actions.async = function() return interrupted end
calls = {}
Executor.ExecuteTaskActions(player, { "async", "after" }, actions)
interrupted.callback("interrupted")
assert(#calls == 0, "interrupted pending action must not run remaining actions")
