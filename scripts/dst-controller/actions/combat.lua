-- Controller combat actions used by configurable button sequences.

local CombatActions = {}

local function GetController(player)
    return player and player.components and player.components.playercontroller or nil
end

-- Run the same controller attack path as DST's native attack control. This keeps
-- client prediction, RPC handling, target selection, and the air-attack setting
-- in one place instead of constructing a partial BufferedAction here.
function CombatActions.attack(player)
    local controller = GetController(player)
    if controller == nil or controller.DoControllerAttackButton == nil then
        return false
    end

    controller:DoControllerAttackButton()
    return true
end

return CombatActions
