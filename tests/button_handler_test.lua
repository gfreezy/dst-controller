local pressed = { LB = false, RB = false }
local tasks = {
    LB_A = {
        on_press = { "press_action" },
        on_release = { "release_action" },
    },
    LB_B = { on_press = {}, on_release = {} },
}

package.loaded["dst-controller/global"] = {
    BUTTON_MAPPINGS = {
        LB = { 1 }, RB = { 2 }, A = { 3 }, B = { 4 },
        X = { 5 }, Y = { 6 }, LT = { 7 }, RT = { 8 },
    },
}
package.loaded["dst-controller/utils/helpers"] = {
    IsButtonPressed = function(name) return pressed[name] == true end,
    DebugPrint = function() end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeTasks = function() return tasks end,
    GetRuntimeSettings = function() return { force_attack_mode = "force_attack" } end,
}
package.loaded["dst-controller/virtual-cursor/core"] = {
    IsCursorModeActive = function() return false end,
}
package.loaded["dst-controller/executor/button-handler"] = nil

local ButtonHandler = require("dst-controller/executor/button-handler")
local onremove
local player = {
    GUID = 101,
    ListenForEvent = function(_, event, callback)
        if event == "onremove" then onremove = callback end
    end,
}
local calls = {}
local function Execute(_, actions)
    table.insert(calls, actions[1] or "empty")
end

pressed.LB = true
assert(ButtonHandler.HandleButtonCombination(player, 3, true, Execute))
assert(calls[1] == "press_action", "combo press should execute its press action")

-- Releasing the modifier first must not lose ownership of the face-button release.
pressed.LB = false
assert(ButtonHandler.HandleButtonCombination(player, 3, false, Execute))
assert(calls[2] == "release_action",
    "captured combo release should execute after the modifier is released first")

-- The release above must clear the pressed flag so the same combo works again.
pressed.LB = true
assert(ButtonHandler.HandleButtonCombination(player, 3, true, Execute))
assert(calls[3] == "press_action", "combo should be reusable after either release order")

pressed.LB = false
ButtonHandler.HandleButtonCombination(player, 3, false, Execute)

-- An explicitly empty task is disabled and should not consume native input.
pressed.LB = true
assert(not ButtonHandler.HandleButtonCombination(player, 4, true, Execute),
    "empty combo tasks should not consume controls")

assert(onremove ~= nil, "player lifecycle cleanup should be installed")
onremove()

-- Cleanup is idempotent and the next input recreates fresh state.
ButtonHandler.RemovePlayer(player)
assert(ButtonHandler.HandleButtonCombination(player, 3, true, Execute))

