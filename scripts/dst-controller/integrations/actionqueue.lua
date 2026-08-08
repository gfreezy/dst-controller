-- Optional ActionQueue RB3 controller bridge.
-- Uses the component's existing selection API without requiring or modifying
-- ActionQueue's source code.

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ConfigManager = require("dst-controller/utils/config_manager")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local ShoulderModifiers = require("dst-controller/integrations/shoulder-modifiers")
local ActionQueueConfig = require("dst-controller/integrations/actionqueue-config")

local ActionQueueIntegration = {}

local MAGNETISM_SOURCE = "actionqueue_selection"

local STATE = {
    modifier_owned_buttons = {},
    captured_button = nil,
    captured_rightclick = false,
    selection_owner = nil,
    selection_snapshot = nil,
    cancel_button_owned = false,
}

local function IsEnabled()
    local settings = ConfigManager.GetRuntimeSettings()
    local cursor_settings = settings and settings.virtual_cursor_settings or nil
    return cursor_settings == nil or cursor_settings.actionqueue_integration ~= false
end

local function GetActionQueuer()
    local player = G.ThePlayer
    local actionqueuer = player and player.components and player.components.actionqueuer or nil
    if actionqueuer == nil or
       type(actionqueuer.OnDown) ~= "function" or
       type(actionqueuer.OnUp) ~= "function" then
        return nil
    end
    return actionqueuer
end

local function IsWorldGameplayContext()
    local player = G.ThePlayer
    if player == nil or not player:IsValid() or player.HUD == nil then
        return false
    end
    if player.HUD:HasInputFocus() then
        return false
    end
    if player.HUD.IsMapScreenOpen ~= nil and player.HUD:IsMapScreenOpen() then
        return false
    end
    return true
end

local function IsPointerOverHud()
    if G.TheInput == nil then
        return false
    end
    if G.TheInput.GetHUDEntityUnderMouse ~= nil and G.TheInput:GetHUDEntityUnderMouse() ~= nil then
        return true
    end
    if G.TheInput.GetWorldEntityUnderMouse ~= nil then
        local entity = G.TheInput:GetWorldEntityUnderMouse()
        if entity ~= nil and entity:HasTag("INLIMBO") then
            return true
        end
    end
    return false
end

local function SafeCall(actionqueuer, method_name, ...)
    local method = actionqueuer and actionqueuer[method_name] or nil
    if type(method) ~= "function" then
        return false
    end

    local success, result = pcall(method, actionqueuer, ...)
    if not success then
        Helpers.DebugPrintf("ActionQueue %s failed: %s", method_name, tostring(result))
        return false
    end
    return true, result
end

local function ResetCapturedState()
    STATE.captured_button = nil
    STATE.captured_rightclick = false
    STATE.selection_owner = nil
    STATE.selection_snapshot = nil
    VirtualCursor.SetMagnetismSuppressed(MAGNETISM_SOURCE, false)
end

local function CopySelection(actionqueuer)
    local snapshot = {}
    for entity, rightclick in pairs(actionqueuer.selected_ents or {}) do
        snapshot[entity] = rightclick
    end
    return snapshot
end

-- OnDown may cherry-pick or toggle an entity immediately. If our drag is
-- interrupted by a screen/context change, restore only that bridge-owned
-- delta instead of erasing selections that existed before the drag.
local function RestoreSelection(actionqueuer, snapshot)
    snapshot = snapshot or {}

    local added_entities = {}
    for entity in pairs(actionqueuer.selected_ents or {}) do
        if snapshot[entity] == nil then
            table.insert(added_entities, entity)
        end
    end
    for _, entity in ipairs(added_entities) do
        SafeCall(actionqueuer, "DeselectEntity", entity)
    end

    for entity, rightclick in pairs(snapshot) do
        if actionqueuer.selected_ents == nil or actionqueuer.selected_ents[entity] == nil then
            SafeCall(actionqueuer, "SelectEntity", entity, rightclick)
        end
    end
end

local function CancelOwnedSelection()
    local actionqueuer = STATE.selection_owner
    if actionqueuer ~= nil then
        SafeCall(actionqueuer, "ClearSelectionThread")
        RestoreSelection(actionqueuer, STATE.selection_snapshot)
        actionqueuer.clicked = false
        actionqueuer.TL, actionqueuer.TR, actionqueuer.BL, actionqueuer.BR = nil, nil, nil, nil
    end
    ResetCapturedState()
end

local function ResetInputState(cancel_selection)
    if cancel_selection and STATE.captured_button ~= nil then
        CancelOwnedSelection()
    else
        ResetCapturedState()
    end
    STATE.modifier_owned_buttons = {}
    STATE.cancel_button_owned = false
end

local function SyncVirtualMousePosition()
    local position = VirtualCursor.GetCursorScreenPosition()
    if position == nil or G.TheInput == nil then
        return
    end
    if G.TheInput.OnMouseMove ~= nil then
        G.TheInput:OnMouseMove(position.x, position.y)
    end
    if G.TheInput.UpdatePosition ~= nil then
        G.TheInput:UpdatePosition(position.x, position.y)
    end
end

local function BeginSelection(actionqueuer, button, rightclick)
    SyncVirtualMousePosition()
    local selection_snapshot = CopySelection(actionqueuer)
    local success = SafeCall(actionqueuer, "OnDown", rightclick)
    if not success then
        SafeCall(actionqueuer, "ClearSelectionThread")
        RestoreSelection(actionqueuer, selection_snapshot)
        actionqueuer.clicked = false
        actionqueuer.TL, actionqueuer.TR, actionqueuer.BL, actionqueuer.BR = nil, nil, nil, nil
        return false
    end

    STATE.captured_button = button
    STATE.captured_rightclick = rightclick
    STATE.selection_owner = actionqueuer
    STATE.selection_snapshot = selection_snapshot
    VirtualCursor.SetMagnetismSuppressed(MAGNETISM_SOURCE, true)
    return true
end

local function FinishSelection()
    local actionqueuer = STATE.selection_owner
    local rightclick = STATE.captured_rightclick
    local success = SafeCall(actionqueuer, "OnUp", rightclick)

    if not success and actionqueuer ~= nil then
        SafeCall(actionqueuer, "ClearSelectionThread")
        RestoreSelection(actionqueuer, STATE.selection_snapshot)
        actionqueuer.clicked = false
    end

    ResetCapturedState()
end

local function CancelQueue(actionqueuer)
    -- Do not call ActionQueue:ClearAllThreads(). RB3 4.0 kills its selection
    -- widget there because that method is intended for component removal.
    SafeCall(actionqueuer, "ClearActionThread")
    SafeCall(actionqueuer, "ClearSelectionThread")
    SafeCall(actionqueuer, "ClearSelectedEntities")
    actionqueuer.clicked = false
    actionqueuer.TL, actionqueuer.TR, actionqueuer.BL, actionqueuer.BR = nil, nil, nil, nil
    ResetCapturedState()
end

local function GetClickButton(control)
    local left_button = VirtualCursor.GetClickButtonName("left")
    if control == G.CONTROL_MENU_L2 and Helpers.IsControlNamedButton(control, left_button) then
        return "left", false
    end

    local right_button = VirtualCursor.GetClickButtonName("right")
    if control == G.CONTROL_MENU_R2 and Helpers.IsControlNamedButton(control, right_button) then
        return "right", true
    end

    return nil, nil
end

local function HasQueueWork(actionqueuer)
    return STATE.captured_button ~= nil or
           actionqueuer.selection_thread ~= nil or
           actionqueuer.action_thread ~= nil or
           (actionqueuer.selected_ents ~= nil and next(actionqueuer.selected_ents) ~= nil)
end

local function IsModifierDown()
    -- FrontEnd does not consistently emit dedicated shoulder OnControl events
    -- after virtual cursor mode switches to the mouse input scheme. Resolve the
    -- queue modifier from both mods' configuration and poll physical state.
    local queue_modifier = ActionQueueConfig.GetModifier()
    for button in pairs(STATE.modifier_owned_buttons) do
        if ShoulderModifiers.IsButtonQueueModifier(button, queue_modifier) then
            return true
        end
    end
    return ShoulderModifiers.IsQueueModifierDown(queue_modifier)
end

local function GetShoulderButton(control)
    for _, button in ipairs({ "LB", "RB" }) do
        if Helpers.IsControlNamedButton(control, button) then
            return button
        end
    end
end

-- Called before the normal virtual mouse button handler.
function ActionQueueIntegration.OnControl(control, down)
    if not VirtualCursor.IsCursorModeActive() or not IsEnabled() then
        if STATE.captured_button ~= nil then
            CancelOwnedSelection()
        end
        STATE.modifier_owned_buttons = {}
        return false
    end

    local button, rightclick = GetClickButton(control)

    -- A captured click owns its matching release even if the configured
    -- shoulder was released or the gameplay context changed in the meantime.
    if STATE.captured_button ~= nil and button ~= nil then
        if not down and button == STATE.captured_button then
            if IsWorldGameplayContext() then
                FinishSelection()
            else
                CancelOwnedSelection()
            end
        end
        return true
    end

    local actionqueuer = GetActionQueuer()
    local valid_context = actionqueuer ~= nil and IsWorldGameplayContext()

    local shoulder_button = GetShoulderButton(control)
    if shoulder_button ~= nil then
        local is_queue_modifier = ShoulderModifiers.IsButtonQueueModifier(
            shoulder_button, ActionQueueConfig.GetModifier())
        if down and valid_context and is_queue_modifier then
            STATE.modifier_owned_buttons[shoulder_button] = true
            return true
        elseif not down and STATE.modifier_owned_buttons[shoulder_button] then
            STATE.modifier_owned_buttons[shoulder_button] = nil
            return true
        end
        return false
    end

    if Helpers.IsControlNamedButton(control, "B") then
        -- Keep normal B/alternate actions available. Queue cancellation belongs
        -- to whichever configured shoulder currently matches ActionQueue's key.
        if down and IsModifierDown() and valid_context and HasQueueWork(actionqueuer) then
            CancelQueue(actionqueuer)
            STATE.cancel_button_owned = true
            return true
        elseif not down and STATE.cancel_button_owned then
            STATE.cancel_button_owned = false
            return true
        end
    end

    if button ~= nil and down and IsModifierDown() and valid_context and not IsPointerOverHud() then
        return BeginSelection(actionqueuer, button, rightclick)
    end

    return false
end

function ActionQueueIntegration.OnCursorModeChanged(active)
    if not active then
        ResetInputState(true)
    end
end

function ActionQueueIntegration.OnUpdate()
    local cursor_active = VirtualCursor.IsCursorModeActive()
    local integration_enabled = IsEnabled()
    local actionqueuer = cursor_active and integration_enabled and GetActionQueuer() or nil
    local valid_context = actionqueuer ~= nil and IsWorldGameplayContext()

    if STATE.captured_button ~= nil and not valid_context then
        CancelOwnedSelection()
    end

    if not valid_context then
        STATE.modifier_owned_buttons = {}
        STATE.cancel_button_owned = false
    end
end

function ActionQueueIntegration.IsAvailable()
    return GetActionQueuer() ~= nil
end

function ActionQueueIntegration.IsSelecting()
    return STATE.captured_button ~= nil
end

return ActionQueueIntegration
