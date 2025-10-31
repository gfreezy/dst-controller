-- Enhanced Controller - PlayerController Hook
-- Hooks PlayerController:OnControl to handle button combinations

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ButtonHandler = require("dst-controller/core/button-handler")
local ActionExecutor = require("dst-controller/core/action-executor")
local ConfigManager = require("dst-controller/utils/config_manager")
local ACTIONS = require("dst-controller/actions/init")
local TargetSelection = require("dst-controller/target-selection/core")
local TaskConfigHook = require("dst-controller/hooks/taskconfig-hook")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local VirtualCursorHook = require("dst-controller/hooks/virtual-cursor-hook")

local ControllerHook = {}

-- Install the PlayerController hook
function ControllerHook.Install()
    G.AddComponentPostInit("playercontroller", function(self)

        -- Override UpdateControllerTargets with our custom implementation
        self.UpdateControllerTargets = function(self, dt)
            -- Use custom target selection logic from target-selection/core.lua
            -- Configuration is loaded dynamically from ConfigManager
            TargetSelection.UpdateControllerTargets(self, dt)
        end

        Helpers.DebugPrint("Initializing Enhanced Controller")

        -- Load task configuration from ConfigManager
        local TASKS = ConfigManager.LoadTasks()

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
            if Helpers.IsControlNamedButton(control, "LB") or Helpers.IsControlNamedButton(control, "RB") then
                return true
            end
            
            -- If LB or RB is pressed, block all controls to prevent default HUD actions
            if Helpers.IsControlNamedButton(control, "LB") or Helpers.IsControlNamedButton(control, "RB") then
                Helpers.DebugPrint("Controller OnControl: block all controls to prevent default HUD actions")
                return false
            end

            -- Check task config screen shortcut
            if TaskConfigHook.OnControl(control, down) then
                return true
            end

            -- Check virtual cursor shortcut
            if VirtualCursorHook.OnControl(self, control, down) then
                return true
            end

            local player = self.inst

            -- Get latest TASKS configuration from ConfigManager
            local current_tasks = ConfigManager.GetRuntimeTasks()

            -- Try to handle as button combination
            local handled = ButtonHandler.HandleButtonCombination(
                player,
                control,
                down,
                current_tasks,
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

        -- Hook UsingMouse to return true when virtual cursor is active
        local old_UsingMouse = self.UsingMouse
        self.UsingMouse = function(self)
            if VirtualCursor.IsCursorModeActive() then
                return true  -- Pretend we're using mouse
            end
            return old_UsingMouse(self)
        end

        -- Store original OnUpdate
        local old_OnUpdate = self.OnUpdate

        -- Override OnUpdate to handle continuous right stick input
        self.OnUpdate = function(self, dt)
            -- Note: Hover entity detection is automatic!
            -- DST's Input:OnUpdate() calls GetEntitiesAtScreenPoint(TheSim:GetPosition())
            -- which uses our hooked GetPosition, so hoverinst is automatically correct.

            -- If cursor mode is active, update cursor position from right stick
            if VirtualCursor.IsCursorModeActive() then
                -- Check if LB is pressed
                local lb_pressed = Helpers.IsButtonPressed("LB")

                -- Only move cursor if LB is NOT pressed
                if not lb_pressed then
                    -- Read right stick input
                    local stick_x = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_RIGHT)
                                  - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_LEFT)
                    local stick_y = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_UP)
                                  - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_DOWN)

                    -- Update cursor position
                    VirtualCursor.UpdateCursorPosition(dt, stick_x, stick_y)

                    -- Update cursor widget drag state
                    if self._cursor_widget then
                        self._cursor_widget:UpdateDragState(VirtualCursor.IsDragging())
                    end

                    return true
                end
            end

            -- Call original OnUpdate
            return old_OnUpdate(self, dt)
        end

    end)
end

return ControllerHook
