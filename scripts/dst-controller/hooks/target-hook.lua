-- Enhanced Controller - Target Selection Hook
-- Hooks UpdateControllerTargets to customize target selection behavior

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local TargetSelection = require("dst-controller/target-selection/core")

local TargetHook = {}

-- Install target selection hook
-- Parameters:
--   config: Mod configuration table
function TargetHook.Install(config)
    -- Set configuration in TargetSelection module
    TargetSelection.SetConfig(config)

    G.AddComponentPostInit("playercontroller", function(controller)
        -- Override UpdateControllerTargets with our custom implementation
        controller.UpdateControllerTargets = function(self, dt)
            -- Use custom target selection logic from target-selection/core.lua
            TargetSelection.UpdateControllerTargets(self, dt)
        end

        Helpers.DebugPrint("Target selection hook installed (using custom target-selection/core.lua)")
        Helpers.DebugPrintf("  - Attack angle mode: %s", config.attack_angle_mode)
        Helpers.DebugPrintf("  - Force attack mode: %s", config.force_attack_mode)
    end)
end

return TargetHook
