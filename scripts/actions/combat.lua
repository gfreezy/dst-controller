-- Enhanced Controller - Combat Actions
-- Attack and combat-related actions

local CombatActions = {}

-- Attack only hostile targets (enemies actively attacking or tagged as hostile)
-- Will not attack neutral or friendly creatures
function CombatActions.attack(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Get controller attack target
    local target = player.components.playercontroller.controller_attack_target

    if not target then
        print("[Enhanced Controller] Attack: No target available")
        return
    end

    -- Check if target is hostile (actively attacking player or tagged as hostile)
    local is_hostile = false

    -- Check if target is actively targeting the player
    if target.replica.combat then
        local target_target = target.replica.combat:GetTarget()
        if target_target == player then
            is_hostile = true
        end
    end

    -- Check if target has hostile tag
    if target:HasTag("hostile") or target:HasTag("monster") then
        is_hostile = true
    end

    -- Only attack if target is hostile
    if is_hostile then
        player.components.playercontroller:DoControllerAttackButton(target)
        print("[Enhanced Controller] Action: Attack (Hostile only)")
    else
        print("[Enhanced Controller] Attack: Target is not hostile (use force_attack to attack anyway)")
    end
end

-- Force attack (even allies) using controller targeting
function CombatActions.force_attack(player)
    if not player.components.playercontroller then
        print("[Enhanced Controller] Error: No playercontroller component")
        return
    end

    -- Get controller attack target or current combat target
    local target = player.components.playercontroller.controller_attack_target
    if not target and player.components.combat then
        target = player.components.combat:GetTarget()
    end

    if target then
        local action = BufferedAction(player, target, ACTIONS.ATTACK)
        action.action.canforce = true  -- Enable force attack
        player.components.playercontroller:DoAction(action)
        print("[Enhanced Controller] Action: Force Attack (Controller)")
    else
        print("[Enhanced Controller] Force Attack: No target available")
    end
end

return CombatActions
