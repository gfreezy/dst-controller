-- Enhanced Controller - Character-Specific Actions
-- Actions specific to certain characters

local G = require("dst-controller/global")
local ActionHelpers = require("dst-controller/actions/helpers")

local CharacterActions = {}

-- ============================================================================
-- Willow-Specific Actions
-- ============================================================================

-- Willow: Cast pyrokinetic spell (requires willow_ember item)
function CharacterActions.willow_cast_spell(player)
    local inventory = ActionHelpers.GetInventory(player)
    if not inventory then return end
    local controller = ActionHelpers.GetPlayerController(player)

    -- Find willow_ember using helper function
    local ember = ActionHelpers.FindItemByName(player, "willow_ember")
    if ember then
        -- Get target position: use controller attack target position, or position in front of player
        local target_pos = nil

        -- Try to use controller attack target position if available
        if controller then
            local controller_target = controller.controller_attack_target
            if controller_target and controller_target:IsValid() then
                target_pos = controller_target:GetPosition()
            end
        end

        -- If no controller target, cast at position in front of player
        if not target_pos then
            local player_pos = player:GetPosition()
            local player_angle = player.Transform:GetRotation() * G.DEGREES
            local cast_distance = 3  -- Distance in front of player
            target_pos = G.Vector3(
                player_pos.x + math.cos(player_angle) * cast_distance,
                0,
                player_pos.z - math.sin(player_angle) * cast_distance
            )
        end

        -- In client mode, we can't check CanCast (server-side component)
        -- The server will reject the action if it can't be performed
        -- Just submit the action and let the server handle validation

        if controller then
            local action = G.BufferedAction(player, nil, G.ACTIONS.CASTAOE, ember, target_pos)
            controller:DoAction(action)
            print(string.format("[Enhanced Controller] Action: Willow Cast Spell at (%.1f, %.1f, %.1f)",
                target_pos.x, target_pos.y, target_pos.z))
        else
            print("[Enhanced Controller] Willow cast spell failed: No playercontroller")
        end
    else
        print("[Enhanced Controller] Willow ember not found in inventory")
    end
end

-- ============================================================================
-- Channeling Actions (used by multiple characters)
-- ============================================================================

-- Start channeling with the currently equipped item
function CharacterActions.start_channeling(player)
    local inventory = ActionHelpers.GetInventory(player)
    local controller = ActionHelpers.GetPlayerController(player)
    if not inventory or not controller then return end

    local equipped = inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)
    if not equipped then
        print("[Enhanced Controller] Cannot start channeling: No item equipped")
        return
    end

    local action = G.BufferedAction(player, nil, G.ACTIONS.START_CHANNELCAST, equipped)
    controller:DoAction(action)
    print(string.format("[Enhanced Controller] Action: Started channeling (%s)", equipped.prefab))
end

-- Stop channeling
function CharacterActions.stop_channeling(player)
    local controller = ActionHelpers.GetPlayerController(player)
    if not controller then return end

    local action = G.BufferedAction(player, nil, G.ACTIONS.STOP_CHANNELCAST)
    controller:DoAction(action)
    print("[Enhanced Controller] Action: Stopped channeling")
end

return CharacterActions
