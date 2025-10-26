-- Enhanced Controller - PlayerController Hook
-- Hooks PlayerController:OnControl to handle button combinations

local G = require("global")
local Helpers = require("utils/helpers")
local ButtonHandler = require("core/button-handler")
local ActionExecutor = require("core/action-executor")
local TASKS = require("config/tasks")
local ACTIONS = require("actions/init")

local ControllerHook = {}

-- Install the PlayerController hook
function ControllerHook.Install()
    G.AddComponentPostInit("playercontroller", function(self)
        Helpers.DebugPrint("Initializing Enhanced Controller")

        -- Log task configuration
        Helpers.DebugPrint("Task Configuration:")
        for task_name, task in pairs(TASKS) do
            Helpers.DebugPrintf("  - %s: %d on_press, %d on_release",
                task_name, #task.on_press, #task.on_release)
        end

        -- Initialize button state for this player
        if self.inst and self.inst.GUID then
            ButtonHandler.InitializePlayer(self.inst)
            ACTIONS.InitEquipmentTracking(self.inst)
        end

        -- Hook OnControl to handle button combinations
        local OldOnControl = self.OnControl
        self.OnControl = function(self, control, down)
            local player = self.inst

            -- Helpers.DebugPrintf("OnControl: control=%d, down=%s", control, tostring(down))

            -- Try to handle as button combination
            local handled = ButtonHandler.HandleButtonCombination(
                player,
                control,
                down,
                TASKS,
                function(p, action_list)
                    ActionExecutor.ExecuteTaskActions(p, action_list, ACTIONS)
                end
            )

            -- If handled as combination, block default behavior
            if handled then
                return true
            end

            -- Otherwise, use default behavior
            return OldOnControl(self, control, down)
        end

        -- returns: enable/disable, "a hud element is up, but still allow for limited gameplay to happen"
        function self:IsEnabled()
            if self.classified == nil or not self.classified.iscontrollerenabled:value() then
                return false
            elseif self.inst.HUD ~= nil and self.inst.HUD:HasInputFocus() then
                return false, self.inst.HUD:IsCraftingOpen() or self.inst.HUD:IsSpellWheelOpen() or (self.command_wheel_allows_gameplay and self.inst.HUD:IsCommandWheelOpen()) or self.inst.HUD:IsControllerInventoryOpen()
            end
            return true
        end

    end)
end

return ControllerHook
