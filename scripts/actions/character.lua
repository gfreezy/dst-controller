-- Enhanced Controller - Character-Specific Actions
-- Actions specific to certain characters

local G = require("global")
local ActionHelpers = require("actions/helpers")

local CharacterActions = {}

-- ============================================================================
-- Willow-Specific Actions
-- ============================================================================

-- Willow: Cast pyrokinetic spell (requires willow_ember item)
function CharacterActions.willow_cast_spell(player)
    if not player.components.inventory then return end

    -- Find willow_ember using helper function
    local ember = ActionHelpers.FindItemByName(player, "willow_ember")

    if ember and ember.components.aoespell then
        -- Get target position: use controller attack target position, or position in front of player
        local target_pos = nil

        -- Try to use controller attack target position if available
        if player.components.playercontroller then
            local controller_target = player.components.playercontroller.controller_attack_target
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

        -- Try to cast the spell
        if ember.components.aoespell:CanCast(player, target_pos) then
            -- Create buffered action to cast AOE spell
            local action = G.BufferedAction(player, nil, G.ACTIONS.CASTAOE, ember, target_pos)
            if player.components.playercontroller then
                player.components.playercontroller:DoAction(action)
                print(string.format("[Enhanced Controller] Action: Willow Cast Spell at (%.1f, %.1f, %.1f)",
                    target_pos.x, target_pos.y, target_pos.z))
            end
        else
            print("[Enhanced Controller] Willow cannot cast spell (not enough embers or cooldown)")
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
    if not player.components.channelcaster then return end

    local equipped = player.components.inventory:GetEquippedItem(G.EQUIPSLOTS.HANDS)
    if equipped and equipped.components.channelcastable then
        player.components.channelcaster:StartChanneling(equipped)
        print(string.format("[Enhanced Controller] Action: Started channeling (%s)", equipped.prefab))
    else
        print("[Enhanced Controller] Cannot start channeling: No channelable item equipped")
    end
end

-- Stop channeling
function CharacterActions.stop_channeling(player)
    if player.components.channelcaster and player.components.channelcaster.channeling then
        player.components.channelcaster:StopChanneling()
        print("[Enhanced Controller] Action: Stopped channeling")
    end
end

return CharacterActions
