-- Maps LB/RB to configured keyboard modifiers while virtual cursor mode is
-- active. State is reconciled by polling as well as events because switching
-- DST to mouse mode can swallow controller shoulder releases.

local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")
local InputHook = require("dst-controller/hooks/input-hook")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local ShoulderModifiers = {}

local BUTTONS = { "LB", "RB" }
local SOURCES = {
    LB = "virtual_cursor_shoulder_LB",
    RB = "virtual_cursor_shoulder_RB",
}
local STATE = {
    down = { LB = false, RB = false },
    modifier = { LB = nil, RB = nil },
}

local function GetConfiguredModifier(button)
    local settings = ConfigManager.GetRuntimeSettings()
    local cursor = settings and settings.virtual_cursor_settings or nil
    local mappings = cursor and cursor.modifier_keys or nil
    return mappings and mappings[button] or "shift"
end

local function SetButtonState(button, down)
    local modifier = GetConfiguredModifier(button)
    local previous_modifier = STATE.modifier[button]
    if STATE.down[button] == down and
       (not down or previous_modifier == modifier) then
        return
    end

    if STATE.down[button] and previous_modifier ~= nil and
       (not down or previous_modifier ~= modifier) then
        InputHook.ClearVirtualModifier(SOURCES[button])
    end

    STATE.down[button] = down
    STATE.modifier[button] = down and modifier or nil
    if down then
        InputHook.SetVirtualModifier(SOURCES[button], modifier, true)
    end
end

local function ClearAll()
    for _, button in ipairs(BUTTONS) do
        SetButtonState(button, false)
    end
end

-- Update state immediately, but let higher-level handlers decide whether the
-- controller event itself should be consumed.
function ShoulderModifiers.OnControl(control, down)
    if not VirtualCursor.IsCursorModeActive() then
        ClearAll()
        return false
    end
    for _, button in ipairs(BUTTONS) do
        if Helpers.IsControlNamedButton(control, button) then
            SetButtonState(button, down)
            return true
        end
    end
    return false
end

function ShoulderModifiers.OnUpdate()
    if not VirtualCursor.IsCursorModeActive() then
        ClearAll()
        return
    end
    for _, button in ipairs(BUTTONS) do
        SetButtonState(button, Helpers.IsButtonPressed(button))
    end
end

function ShoulderModifiers.OnCursorModeChanged(active)
    if not active then
        ClearAll()
        return
    end
    ShoulderModifiers.OnUpdate()
end

function ShoulderModifiers.GetConfiguredModifier(button)
    return GetConfiguredModifier(button)
end

function ShoulderModifiers.IsButtonQueueModifier(button, queue_modifier)
    return queue_modifier ~= nil and
        GetConfiguredModifier(button) == queue_modifier
end

function ShoulderModifiers.IsQueueModifierDown(queue_modifier)
    if queue_modifier == nil or not VirtualCursor.IsCursorModeActive() then
        return false
    end
    for _, button in ipairs(BUTTONS) do
        if GetConfiguredModifier(button) == queue_modifier and
           Helpers.IsButtonPressed(button) then
            return true
        end
    end
    return false
end

function ShoulderModifiers._ResetForTests()
    ClearAll()
    STATE.down = { LB = false, RB = false }
    STATE.modifier = { LB = nil, RB = nil }
end

return ShoulderModifiers
