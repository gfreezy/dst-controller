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
    G.AddComponentPostInit("playercontroller", function(inst)
        Helpers.DebugPrint("Initializing Enhanced Controller")

        -- Log task configuration
        Helpers.DebugPrint("Task Configuration:")
        for task_name, task in pairs(TASKS) do
            Helpers.DebugPrintf("  - %s: %d on_press, %d on_release",
                task_name, #task.on_press, #task.on_release)
        end

        -- Initialize button state for this player
        if inst.inst and inst.inst.GUID then
            ButtonHandler.InitializePlayer(inst.inst)
            ACTIONS.InitEquipmentTracking(inst.inst)
        end

        -- Hook OnControl to handle button combinations
        local OldOnControl = inst.OnControl
        inst.OnControl = function(self, control, down)
            local player = self.inst

            Helpers.DebugPrintf("OnControl: control=%d, down=%s", control, tostring(down))

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
    end)
end

return ControllerHook
