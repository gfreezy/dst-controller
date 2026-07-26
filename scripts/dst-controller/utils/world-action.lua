-- Enhanced Controller - Client world-action dispatch helpers

local G = require("dst-controller/global")

local WorldAction = {}

local function ActionsMatch(buffered, expected)
    if buffered == nil or buffered.action == nil or expected == nil then
        return false
    end
    if buffered.action == expected then
        return true
    end
    return buffered.action.code == expected.code and
        buffered.action.mod_name == expected.mod_name
end

local function FindSceneAction(controller, target, expected)
    if controller.GetSceneItemControllerAction == nil then
        return nil
    end

    local primary, secondary = controller:GetSceneItemControllerAction(target)
    if ActionsMatch(primary, expected) then
        return primary, false
    end
    if ActionsMatch(secondary, expected) then
        return secondary, true
    end
    return nil
end

local function IsControlReleased(control)
    return G.TheInput == nil or G.TheInput.IsControlPressed == nil or
        not G.TheInput:IsControlPressed(control)
end

local function SendSceneAction(controller, buffered, target, secondary, predicting)
    local control = secondary and G.CONTROL_CONTROLLER_ALTACTION or
        G.CONTROL_CONTROLLER_ACTION
    local rpc = secondary and G.RPC.ControllerAltActionButton or
        G.RPC.ControllerActionButton

    if controller.remote_controls ~= nil then
        controller.remote_controls[control] = 0
    end

    if predicting then
        G.SendRPCToServer(rpc, buffered.action.code, target,
            IsControlReleased(control), nil, buffered.action.mod_name)
    else
        G.SendRPCToServer(rpc, buffered.action.code, target,
            nil, buffered.action.canforce, buffered.action.mod_name)
    end
end

local function DoSceneAction(controller, target, action)
    local buffered, secondary = FindSceneAction(controller, target, action)
    if buffered == nil then
        return false, "scene_action_unavailable"
    end

    if not controller.ismastersim then
        if controller.locomotor == nil then
            buffered.non_preview_cb = function()
                SendSceneAction(controller, buffered, target, secondary, false)
            end
        else
            buffered.preview_cb = function()
                SendSceneAction(controller, buffered, target, secondary, true)
            end
        end
    end

    controller:DoAction(buffered)
    return true
end

local function DoActionButtonAction(controller, player, target, action)
    local buffered = G.BufferedAction(player, target, action)
    if not controller.ismastersim then
        local function SendAction()
            controller:RemoteActionButton(buffered)
        end
        if controller.locomotor == nil then
            buffered.non_preview_cb = SendAction
        else
            buffered.preview_cb = SendAction
        end
    end
    controller:DoAction(buffered)
    return true
end

function WorldAction.Do(player, target, action)
    local controller = player ~= nil and player.components ~= nil and
        player.components.playercontroller or nil
    if controller == nil then
        return false, "controller_unavailable"
    end

    -- RUMMAGE is a scene interaction, not an action-button action. The server
    -- validates it by asking the action picker for the target's controller
    -- action, so use that exact action and matching controller RPC.
    if action == G.ACTIONS.RUMMAGE then
        return DoSceneAction(controller, target, action)
    end

    return DoActionButtonAction(controller, player, target, action)
end

WorldAction.FindSceneAction = FindSceneAction

return WorldAction
