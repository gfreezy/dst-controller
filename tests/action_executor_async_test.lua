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

local completed_sequence = Executor.ExecuteTaskActions(player, { "async", "after" }, actions)
assert(#calls == 1 and calls[1] == "async", "pending action must pause the task sequence")
pending.callback("success")
assert(#calls == 2 and calls[2] == "after", "successful pending action must resume the sequence")
assert(completed_sequence.status == "success", "completed sequences should expose their status")

local interrupted = { pending = true }
function interrupted:OnComplete(callback) self.callback = callback end
actions.async = function() return interrupted end
calls = {}
local interrupted_sequence = Executor.ExecuteTaskActions(player, { "async", "after" }, actions)
interrupted.callback("interrupted")
assert(#calls == 0, "interrupted pending action must not run remaining actions")
assert(interrupted_sequence.status == "interrupted",
    "pending failures should propagate to the sequence status")

-- Starting another sequence must invalidate a delayed callback from the old one.
local delayed_callback
local delayed_cancelled = false
player.DoTaskInTime = function(_, _, callback)
    delayed_callback = callback
    return { Cancel = function() delayed_cancelled = true end }
end
actions.equip_item = function() table.insert(calls, "equip") end
actions.replacement = function() table.insert(calls, "replacement") end
calls = {}
local replaced = Executor.ExecuteTaskActions(player, { "equip_item", "after" }, actions)
assert(calls[1] == "equip" and delayed_callback ~= nil,
    "an auto-delay should schedule the rest of the sequence")
Executor.ExecuteTaskActions(player, { "replacement" }, actions)
assert(replaced.status == "cancelled" and delayed_cancelled,
    "a new shortcut should cancel the old delayed sequence")
delayed_callback()
assert(#calls == 2 and calls[2] == "replacement",
    "a stale delayed callback must not run after replacement")

-- Action errors and unknown action names stop the sequence without escaping input handling.
actions.explode = function() error("boom") end
calls = {}
local failed = Executor.ExecuteTaskActions(player, { "explode", "after" }, actions)
assert(failed.status == "failed" and #calls == 0,
    "action errors should be isolated and stop dependent actions")
local unknown = Executor.ExecuteTaskActions(player, { "missing_action", "after" }, actions)
assert(unknown.status == "failed", "unknown actions should fail the sequence explicitly")
