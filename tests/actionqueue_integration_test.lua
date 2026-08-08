local RB, B, LT, RT = 11, 12, 13, 14
local cursor_active = true
local magnetism_suppressed = false
local pressed = { LB = false, RB = false }
local modifier_mappings = { LB = "shift", RB = "alt" }
local queue_modifier = "shift"

local existing = { name = "existing" }
local added = { name = "added" }

local actionqueuer = {
    selected_ents = { [existing] = false },
    action_thread = {},
}

function actionqueuer:OnDown()
    self.clicked = true
    self.selected_ents[added] = false
end

function actionqueuer:OnUp()
    self.clicked = false
end

function actionqueuer:ClearSelectionThread()
    self.selection_thread = nil
end

function actionqueuer:ClearActionThread()
    self.action_thread = nil
end

function actionqueuer:ClearSelectedEntities()
    self.selected_ents = {}
end

function actionqueuer:DeselectEntity(entity)
    self.selected_ents[entity] = nil
end

function actionqueuer:SelectEntity(entity, rightclick)
    self.selected_ents[entity] = rightclick
end

local hud = {
    HasInputFocus = function() return false end,
    IsMapScreenOpen = function() return false end,
}

local player = {
    HUD = hud,
    components = { actionqueuer = actionqueuer },
    IsValid = function() return true end,
}

package.loaded["dst-controller/global"] = {
    ThePlayer = player,
    TheInput = {
        GetHUDEntityUnderMouse = function() return nil end,
        GetWorldEntityUnderMouse = function() return nil end,
        OnMouseMove = function() end,
        UpdatePosition = function() end,
    },
    CONTROL_MENU_L2 = LT,
    CONTROL_MENU_R2 = RT,
}
package.loaded["dst-controller/utils/helpers"] = {
    IsControlNamedButton = function(control, name)
        return (name == "LB" and control == 10) or
            (name == "RB" and control == RB) or
            (name == "B" and control == B) or
            (name == "LT" and control == LT) or
            (name == "RT" and control == RT)
    end,
    IsButtonPressed = function(name)
        return pressed[name] == true
    end,
    DebugPrintf = function() end,
}
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeSettings = function()
        return { virtual_cursor_settings = { actionqueue_integration = true } }
    end,
}
package.loaded["dst-controller/virtual-cursor/core"] = {
    IsCursorModeActive = function() return cursor_active end,
    GetClickButtonName = function(side) return side == "left" and "LT" or "RT" end,
    GetCursorScreenPosition = function() return { x = 100, y = 100 } end,
    SetMagnetismSuppressed = function(_, suppressed) magnetism_suppressed = suppressed end,
}
package.loaded["dst-controller/integrations/shoulder-modifiers"] = {
    IsButtonQueueModifier = function(button, modifier)
        return modifier_mappings[button] == modifier
    end,
    IsQueueModifierDown = function(modifier)
        for button, down in pairs(pressed) do
            if down and modifier_mappings[button] == modifier then
                return true
            end
        end
        return false
    end,
}
package.loaded["dst-controller/integrations/actionqueue-config"] = {
    GetModifier = function() return queue_modifier end,
}
package.loaded["dst-controller/integrations/actionqueue"] = nil

local ActionQueueIntegration = require("dst-controller/integrations/actionqueue")

assert(ActionQueueIntegration.OnControl(B, true) == false, "plain B must remain available")
assert(actionqueuer.action_thread ~= nil, "plain B must not cancel ActionQueue")

assert(ActionQueueIntegration.OnControl(RB, true) == false,
    "a shoulder mapped to Alt must not be captured for a Shift ActionQueue key")
assert(ActionQueueIntegration.OnControl(10, true) == true,
    "the configured LB Shift modifier should be captured")
assert(ActionQueueIntegration.OnControl(B, true) == true,
    "the configured queue modifier plus B should cancel ActionQueue")
assert(actionqueuer.action_thread == nil,
    "the configured queue shortcut should clear queued actions")
assert(ActionQueueIntegration.OnControl(B, false) == true,
    "the queue-cancel release should be captured")
assert(ActionQueueIntegration.OnControl(10, false) == true,
    "the configured shoulder release should be captured")

actionqueuer.selected_ents = { [existing] = false }
assert(ActionQueueIntegration.OnControl(10, true) == true,
    "LB should start another configured modified input")
assert(ActionQueueIntegration.OnControl(LT, true) == true,
    "configured shoulder plus LT should start selection")
assert(magnetism_suppressed == true, "selection should suppress cursor magnetism")
assert(actionqueuer.selected_ents[added] ~= nil, "selection setup should add its owned entity")

ActionQueueIntegration.OnCursorModeChanged(false)

assert(actionqueuer.selected_ents[existing] ~= nil, "interrupted selection should preserve prior selection")
assert(actionqueuer.selected_ents[added] == nil, "interrupted selection should remove only its own delta")
assert(magnetism_suppressed == false, "interrupted selection should restore cursor magnetism")

-- Mouse input mode may omit a shoulder OnControl event. Its configured and
-- polled physical state must still activate the modifier when LT/RT arrives.
modifier_mappings.LB = "alt"
modifier_mappings.RB = "shift"
pressed.RB = true
assert(ActionQueueIntegration.OnControl(LT, true) == true,
    "a physically held configured shoulder should work without its OnControl event")
assert(magnetism_suppressed == true,
    "polled configured selection should suppress cursor magnetism")
pressed.RB = false
assert(ActionQueueIntegration.OnControl(LT, false) == true,
    "the captured selection release should finish after the shoulder is released")
assert(magnetism_suppressed == false,
    "finished polled selection should restore cursor magnetism")
