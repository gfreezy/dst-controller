local pressed = { LB = false, RB = false }
local virtual_cursor_active = false
local tasks = {
    LB_A = {
        on_press = { "press_action" },
        on_release = { "release_action" },
    },
    LB_B = { on_press = {}, on_release = {} },
    LB_LT = {
        on_press = { "lb_lt_press" },
        on_release = { "lb_lt_release" },
    },
    LB_DPAD_UP = {
        on_press = { "lb_dpad_press" },
        on_release = { "lb_dpad_release" },
    },
    LB_DPAD_DOWN = { on_press = {}, on_release = {} },
    RB_DPAD_UP = {
        on_press = { "rb_dpad_press" },
        on_release = {},
    },
    RB_DPAD_DOWN = {
        on_press = { "rb_dpad_down_press" },
        on_release = {},
    },
}

package.loaded["dst-controller/global"] = {
    BUTTON_MAPPINGS = {
        LB = { 1 }, RB = { 2 }, A = { 3 }, B = { 4 },
        X = { 5 }, Y = { 6 }, LT = { 7 }, RT = { 8 },
        DPAD_UP = { 9, 19, 29 },
        DPAD_DOWN = { 10, 20, 30 },
        DPAD_LEFT = { 11, 21, 31 },
        DPAD_RIGHT = { 12, 22, 32 },
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
    IsCursorModeActive = function() return virtual_cursor_active end,
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

ButtonHandler.ClearPressedStates(player)
assert(ButtonHandler.HandleButtonCombination(player, 3, true, Execute))
assert(calls[4] == "press_action",
    "a modal screen should be able to clear a swallowed combo release")

pressed.LB = false
ButtonHandler.HandleButtonCombination(player, 3, false, Execute)

-- PlayerHud checks the shoulder's live digital state before deciding whether
-- LT/RT should open the crafting menu or inventory.
pressed.LB = true
assert(ButtonHandler.ShouldHandleControl(player, 7, true),
    "a live LB should route configured LB+LT past native HUD handling")
assert(ButtonHandler.HandleButtonCombination(player, 7, true, Execute))
assert(calls[#calls] == "lb_lt_press",
    "the routed LB+LT press should execute its configured action")
pressed.LB = false
assert(ButtonHandler.ShouldHandleControl(player, 7, false),
    "captured LT release should route after LB is released first")
assert(ButtonHandler.HandleButtonCombination(player, 7, false, Execute))
assert(calls[#calls] == "lb_lt_release",
    "captured LB+LT release actions should execute exactly once")

virtual_cursor_active = true
assert(not ButtonHandler.HandleButtonCombination(player, 7, true, Execute) and
       not ButtonHandler.HandleButtonCombination(player, 8, true, Execute),
    "cursor-mode LT/RT must remain reserved for virtual mouse clicks")
virtual_cursor_active = false

-- An explicitly empty task is disabled and should not consume native input.
pressed.LB = true
assert(not ButtonHandler.HandleButtonCombination(player, 4, true, Execute),
    "empty combo tasks should not consume controls")

pressed.LB = false
assert(not ButtonHandler.HandleButtonCombination(player, 3, true, Execute),
    "a bare A press must not reuse an earlier LB state")

pressed.LB = false
pressed.RB = false
assert(not ButtonHandler.HandleButtonCombination(player, 9, true, Execute),
    "a bare D-pad press must preserve DST's native behavior")

pressed.LB = true
assert(ButtonHandler.HandleButtonCombination(player, 19, true, Execute),
    "LB plus any D-pad-up control alias should execute its configured task")
assert(calls[#calls] == "lb_dpad_press",
    "LB+D-pad should execute the configured press action")
pressed.LB = false
assert(ButtonHandler.HandleButtonCombination(player, 29, false, Execute),
    "the captured D-pad release should survive releasing LB first")
assert(calls[#calls] == "lb_dpad_release",
    "LB+D-pad should execute the configured release action")

pressed.LB = true
assert(not ButtonHandler.HandleButtonCombination(player, 10, true, Execute),
    "an empty LB+D-pad task must preserve DST's native behavior")

pressed.RB = true
assert(ButtonHandler.HandleButtonCombination(player, 9, true, Execute),
    "when both shoulders are held, the fixed LB priority should avoid duplicate tasks")
assert(calls[#calls] == "lb_dpad_press",
    "the higher-priority LB task should own a shared D-pad event")
ButtonHandler.ClearPressedStates(player)
pressed.LB = false
assert(ButtonHandler.HandleButtonCombination(player, 9, true, Execute),
    "RB+D-pad should execute when LB does not own the combination")
assert(calls[#calls] == "rb_dpad_press",
    "RB+D-pad should use its own configured task")

pressed.LB = true
assert(ButtonHandler.HandleButtonCombination(player, 10, true, Execute),
    "an empty LB combo should allow a configured RB combo to handle the event")
assert(calls[#calls] == "rb_dpad_down_press",
    "priority should apply to the first configured shoulder combo, not an empty one")
assert(not ButtonHandler.HandleButtonCombination(player, 11, true, Execute),
    "a D-pad direction with no task on either held shoulder must fall through")

assert(onremove ~= nil, "player lifecycle cleanup should be installed")
onremove()

-- Cleanup is idempotent and the next input recreates fresh state.
ButtonHandler.RemovePlayer(player)
pressed.LB = true
pressed.RB = false
assert(ButtonHandler.HandleButtonCombination(player, 3, true, Execute))
