-- Enhanced Controller - Inspection Actions
-- Examine and inspect actions

local InspectionActions = {}

-- Examine/inspect target using controller targeting
function InspectionActions.examine(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Use controller_target (for interactable objects) or controller_attack_target (for entities)
    local target = player.components.playercontroller.controller_target or
                   player.components.playercontroller.controller_attack_target

    if target then
        local action = BufferedAction(player, target, ACTIONS.LOOKAT)
        player.components.playercontroller:DoAction(action)
        print("[Enhanced Controller] Action: Examine (Controller)")
    else
        print("[Enhanced Controller] Examine: No target available")
    end
end

-- Inspect self (open character screen)
function InspectionActions.inspect_self(player)
    if player.HUD then
        player.HUD:InspectSelf()
        print("[Enhanced Controller] Action: Inspect Self")
    end
end

return InspectionActions
