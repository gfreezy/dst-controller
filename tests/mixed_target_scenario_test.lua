local function MakeEntity(name, x)
    local tags = {}
    local value = { prefab = name, replica = {}, _x = x }
    value.entity = {
        IsVisible = function() return true end,
        GetParent = function() return nil end,
    }
    value.Transform = {
        GetWorldPosition = function() return x, 0, 0 end,
    }
    function value:IsValid() return true end
    function value:HasTag(tag) return tags[tag] == true end
    function value:AddTestTag(tag) tags[tag] = true end
    function value:GetPosition() return { x = x, y = 0, z = 0 } end
    function value:GetPhysicsRadius() return 0 end
    return value
end

local science = MakeEntity("researchlab", 2)
local campfire = MakeEntity("campfire", 1)
local pitchfork = MakeEntity("pitchfork", 0)
local wood = MakeEntity("log", 0)

local scene_scan_calls = 0
local G = {
    EQUIPSLOTS = { HANDS = "hands" },
    TUNING = { CONTROLLER_INTERACT_ANGLE = 90, CONTROLLER_BOATINTERACT_ANGLE = 90 },
    DEGREES = math.pi / 180,
    CONTROL_CONTROLLER_ATTACK = 1,
    TheInput = { IsControlPressed = function() return false end },
    TheSim = {
        RegisterFindTags = function() return {} end,
        FindEntities = function()
            scene_scan_calls = scene_scan_calls + 1
            return { science, campfire }
        end,
        FindEntities_Registered = function() return {} end,
    },
    CanEntitySeeTarget = function() return true end,
    CanEntitySeePoint = function() return true end,
    FindEntity = function() return nil end,
    FunctionOrValue = function(value) return type(value) == "function" and value() or value end,
    GetPortalRez = function() return false end,
    IsEntityDead = function() return false end,
    anglediff = function(a, b) return a - b end,
}

package.loaded["dst-controller/global"] = G
package.loaded["dst-controller/utils/helpers"] = { IsButtonPressed = function() return false end }
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeSettings = function()
        return {
            attack_angle_mode = "all_around",
            interaction_angle_mode = "all_around",
            force_attack_mode = "hostile_only",
        }
    end,
}
package.loaded["dst-controller/target-selection/core"] = nil

local player = MakeEntity("player", 0)
player.HUD = { IsPlayerAvatarPopUpOpen = function() return false end }
player.replica.inventory = {
    IsHeavyLifting = function() return false end,
    IsFloaterHeld = function() return false end,
    GetEquippedItem = function() return pitchfork end,
}
player.replica.combat = {
    GetAttackRangeWithWeapon = function() return 2 end,
    GetTarget = function() return nil end,
    IsAlly = function() return false end,
    CanTarget = function() return false end,
}
function player:HasTag(tag) return tag == "idle" end
function player:GetCurrentPlatform() return nil end
function player:GetDistanceSqToInst(target) return target._x * target._x end
function player:GetAngleToPoint() return 0 end
player.Transform.GetRotation = function() return 0 end

local controller = {
    inst = player,
    controller_target_age = math.huge,
    controller_targeting_lock_target = false,
    controller_targeting_targets = {},
}
local item_action_queries = 0
function controller:IsAOETargeting() return false end
function controller:GetControllerAttackTarget() return nil end
function controller:GetCursorInventoryObject() return wood end
function controller:GetSceneItemControllerAction(target)
    local terraform = {
        target = nil,
        pos = { x = target._x, y = 0, z = 0 },
        action = { id = "TERRAFORM" },
    }
    if target == science then
        return { target = science, action = { id = "RESEARCH" } }, terraform
    end
    return nil, terraform
end
function controller:GetItemUseAction(item, target)
    item_action_queries = item_action_queries + 1
    if item == wood and target == campfire then
        return { target = campfire, action = { id = "ADDFUEL" } }
    end
end

local TargetSelection = require("dst-controller/target-selection/core")
TargetSelection.UpdateControllerTargets(controller, 0.016)

assert(controller.controller_target == science, "science machine should remain the main target")
assert(controller.controller_alternative_target == nil, "terraform point action must not become an entity alt target")
assert(controller.controller_item_use_target == campfire, "campfire should be the independent wood-use target")

local first_scan_queries = item_action_queries
for _ = 1, 5 do
    TargetSelection.UpdateControllerTargets(controller, 0.016)
end
assert(item_action_queries == first_scan_queries, "item-use target scan should be throttled between intervals")
assert(scene_scan_calls < 6,
    "base target discovery should be throttled instead of scanning every frame")

for _ = 1, 2 do
    TargetSelection.UpdateControllerTargets(controller, 0.016)
end
assert(item_action_queries > first_scan_queries, "item-use target scan should resume after its interval")

-- A nearby player used to keep the dynamic interaction radius too small to
-- discover the Florid Postern, then win HAUNT targeting by distance.
local postern = MakeEntity("multiplayer_portal_moonrock", 4)
postern:AddTestTag("multiplayer_portal")
local nearby_player = MakeEntity("wilson", 0.5)
nearby_player:AddTestTag("player")
function player:HasTag(tag)
    return tag == "idle" or tag == "playerghost"
end
G.GetPortalRez = function() return true end
local ghost_search_radius
G.TheSim.FindEntities = function(_, _, _, _, radius)
    ghost_search_radius = radius
    return { nearby_player, postern }
end
function controller:GetSceneItemControllerAction(target)
    if target == nearby_player or target == postern then
        return { target = target, action = { id = "HAUNT" } }
    end
end
controller.controller_target = nearby_player
controller.controller_target_age = math.huge
controller._enhanced_target_scan_age = 1
controller.controller_item_use_target = nil
controller.controller_item_use_source = nil
TargetSelection.UpdateControllerTargets(controller, 0.016)
assert(ghost_search_radius == 8,
    "ghost resurrection targeting should keep the full interaction scan radius")
assert(controller.controller_target == postern,
    "a usable Florid Postern must outrank a closer player for ghost resurrection")

-- Explicit force-attack commands must bypass both hostile filtering and the
-- short ally-protection cooldown, even when they are rebound away from LB+X.
local neutral = MakeEntity("friendly_creature", 1)
neutral.replica.combat = { GetTarget = function() return nil end }
function player:HasTag(tag) return tag == "idle" end
player.replica.combat.IsAlly = function(_, target) return target == neutral end
player.replica.combat.CanTarget = function(_, target) return target == neutral end
controller.controller_attack_target = nil
controller.controller_attack_target_ally_cd = 1
controller.controller_targeting_lock_target = false
G.TheSim.FindEntities_Registered = function() return { neutral } end
TargetSelection.RefreshControllerAttackTarget(controller, true)
assert(controller.controller_attack_target == neutral,
    "force attack should select a non-hostile ally despite the safety cooldown")
