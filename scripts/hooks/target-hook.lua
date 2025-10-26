-- Enhanced Controller - Target Selection Hook
-- Hooks UpdateControllerTargets to customize target selection behavior

local Helpers = require("utils/helpers")

local TargetHook = {}

-- Install target selection hook
function TargetHook.Install()
    AddComponentPostInit("playercontroller", function(controller)
        -- Store original UpdateControllerTargets function
        local OriginalUpdateControllerTargets = controller.UpdateControllerTargets

        -- Override UpdateControllerTargets
        controller.UpdateControllerTargets = function(self, dt)
            -- Call original function first (uses default DST logic)
            OriginalUpdateControllerTargets(self, dt)

            -- TODO: Add custom target filtering logic here
            -- Currently using default DST behavior

            -- Example: Filter out non-hostile attack targets
            -- if self.controller_attack_target then
            --     local target = self.controller_attack_target
            --     if not TargetHook.IsHostile(target, self.inst) then
            --         self.controller_attack_target = nil
            --     end
            -- end
        end

        Helpers.DebugPrint("Target selection hook installed")
    end)
end

-- Check if a target is hostile
function TargetHook.IsHostile(target, player)
    if not target then return false end

    -- Check if target is actively targeting the player
    if target.replica.combat then
        local target_target = target.replica.combat:GetTarget()
        if target_target == player then
            return true
        end
    end

    -- Check if target has hostile tag
    if target:HasTag("hostile") or target:HasTag("monster") then
        return true
    end

    return false
end

return TargetHook
