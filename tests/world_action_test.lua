local calls = {}
local rumage = { code = 17, mod_name = nil, canforce = true }
local pickup = { code = 23, mod_name = nil }
local G = {
    ACTIONS = { RUMMAGE = rumage, PICKUP = pickup },
    CONTROL_CONTROLLER_ACTION = 1,
    CONTROL_CONTROLLER_ALTACTION = 2,
    RPC = {
        ControllerActionButton = "controller_action",
        ControllerAltActionButton = "controller_alt_action",
    },
    TheInput = {
        IsControlPressed = function() return false end,
    },
    SendRPCToServer = function(...)
        calls.rpc = { ... }
    end,
    BufferedAction = function(player, target, action)
        return { doer = player, target = target, action = action }
    end,
}

package.loaded["dst-controller/global"] = G
package.loaded["dst-controller/utils/world-action"] = nil

local WorldAction = require("dst-controller/utils/world-action")
local target = {}

local function MakeController(locomotor, primary, secondary)
    local controller = {
        ismastersim = false,
        locomotor = locomotor,
        remote_controls = {},
    }
    function controller:GetSceneItemControllerAction(requested)
        assert(requested == target)
        return primary, secondary
    end
    function controller:DoAction(buffered)
        calls.buffered = buffered
        local callback = buffered.preview_cb or buffered.non_preview_cb
        if callback ~= nil then
            callback()
        end
    end
    function controller:RemoteActionButton(buffered)
        calls.action_button = buffered
    end
    return controller
end

local primary = { target = target, action = rumage }
local controller = MakeController({}, primary, nil)
local player = { components = { playercontroller = controller } }
local ok = WorldAction.Do(player, target, rumage)
assert(ok, "RUMMAGE should use an available scene action")
assert(calls.buffered == primary, "the action picker buffer should be executed unchanged")
assert(calls.rpc[1] == "controller_action" and calls.rpc[2] == rumage.code and
    calls.rpc[3] == target and calls.rpc[4] == true,
    "predicted primary scene actions should use the controller action RPC")
assert(calls.action_button == nil,
    "RUMMAGE must not be sent through the generic action-button RPC")

calls = {}
local secondary = { target = target, action = rumage }
controller = MakeController(nil, nil, secondary)
player.components.playercontroller = controller
ok = WorldAction.Do(player, target, rumage)
assert(ok and calls.rpc[1] == "controller_alt_action",
    "secondary scene actions should use the controller alt-action RPC")
assert(calls.rpc[4] == nil and calls.rpc[5] == rumage.canforce,
    "non-predicting clients should preserve the game's no-force argument")

calls = {}
controller = MakeController({}, nil, nil)
player.components.playercontroller = controller
ok = WorldAction.Do(player, target, pickup)
assert(ok and calls.action_button ~= nil,
    "ordinary action-button actions should keep their existing dispatch path")

calls = {}
controller = MakeController({}, nil, nil)
player.components.playercontroller = controller
local reason
ok, reason = WorldAction.Do(player, target, rumage)
assert(not ok and reason == "scene_action_unavailable" and calls.buffered == nil,
    "missing scene actions should fail before starting a misleading walk")
