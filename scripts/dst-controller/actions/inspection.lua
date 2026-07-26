-- Enhanced Controller - Inspection Actions
-- Examine and inspect actions

local Helpers = require("dst-controller/utils/helpers")

local InspectionActions = {}

-- Examine/inspect target using controller targeting
function InspectionActions.examine(player)
    local controller = player.components.playercontroller
    if not controller then
        Helpers.DebugPrint("No player controller component")
        return
    end

    -- Prefer the mod's dedicated examine target, then fall back to native targets.
    local target = controller.GetControllerExamineTarget ~= nil and
                   controller:GetControllerExamineTarget() or
                   controller:GetControllerTarget() or
                   controller:GetControllerAttackTarget()

    if target then
        -- DoInspectButton installs the preview/RPC callbacks required by client
        -- movement prediction. Calling DoAction on a bare LOOKAT BufferedAction
        -- leaves preview_cb nil and crashes in RemoteBufferedAction.
        local original_target = controller.controller_target
        controller.controller_target = target
        controller:DoInspectButton()
        controller.controller_target = original_target
        Helpers.DebugPrint("Action: Examine (Controller)")
    else
        Helpers.DebugPrint("Examine: no target available")
    end
end

-- Inspect self (open character screen)
function InspectionActions.inspect_self(player)
    if player.HUD then
        player.HUD:InspectSelf()
        Helpers.DebugPrint("Action: Inspect Self")
    end
end

return InspectionActions
