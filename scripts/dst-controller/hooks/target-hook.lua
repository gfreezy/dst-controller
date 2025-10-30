-- Enhanced Controller - Target Selection Hook
-- Hooks UpdateControllerTargets to customize target selection behavior

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local TargetSelection = require("dst-controller/target-selection/core")

local TargetHook = {}

-- Install target selection hook
function TargetHook.Install()
    G.AddComponentPostInit("playercontroller", function(controller)
        -- Override UpdateControllerTargets with our custom implementation
        controller.UpdateControllerTargets = function(self, dt)
            -- Use custom target selection logic from target-selection/core.lua
            -- Configuration is loaded dynamically from ConfigManager
            TargetSelection.UpdateControllerTargets(self, dt)
        end

        Helpers.DebugPrint("Target selection hook installed (using custom target-selection/core.lua)")
        Helpers.DebugPrint("  Settings are loaded dynamically from ConfigManager")
    end)
end

return TargetHook
