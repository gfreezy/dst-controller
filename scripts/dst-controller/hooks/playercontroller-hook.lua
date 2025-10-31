-- PlayerController Hook
-- Consolidates ALL playercontroller component hooks in one place
-- Delegates to feature-specific modules for actual logic

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ButtonHandler = require("dst-controller/core/button-handler")
local ActionExecutor = require("dst-controller/core/action-executor")
local ConfigManager = require("dst-controller/utils/config_manager")
local ACTIONS = require("dst-controller/actions/init")
local TargetSelection = require("dst-controller/target-selection/core")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local PlayerControllerHook = {}

-- Hook: UpdateControllerTargets (override)
local function InstallUpdateControllerTargets(self)
    self.UpdateControllerTargets = function(self, dt)
        -- Delegate to target selection module
        TargetSelection.UpdateControllerTargets(self, dt)
    end
end

-- Hook: OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(self, control, down)

        local button_name = Helpers.ControlToButtonName(control)
        print("[PlayerControllerHook] Control to button name:", button_name)

        -- Block further actions for LB/RB when virtual cursor is not active, end event propagation
        if not VirtualCursor.IsCursorModeActive() then
            if Helpers.IsControlAnyOf(control, {"LB", "RB"}) then
                return true
            end
        end

        -- Check virtual cursor controls (toggle combo and cursor buttons)
        if VirtualCursor.OnControl(control, down) then
            return true
        end

        -- Try to handle as button combination
        local handled = ButtonHandler.HandleButtonCombination(
            self.inst,
            control,
            down,
            function(p, action_list)
                ActionExecutor.ExecuteTaskActions(p, action_list, ACTIONS)
            end
        )

        -- If handled, block default behavior
        if handled then
            return true
        end

        -- Otherwise, use default behavior
        return old_OnControl(self, control, down)
    end
end

-- Hook: IsEnabled (override)
local function InstallIsEnabled(self)
    self.IsEnabled = function(self)
        if self.classified == nil or not self.classified.iscontrollerenabled:value() then
            return false
        elseif self.inst.HUD ~= nil and self.inst.HUD:HasInputFocus() then
            return false, self.inst.HUD:IsCraftingOpen() or self.inst.HUD:IsSpellWheelOpen() or (self.command_wheel_allows_gameplay and self.inst.HUD:IsCommandWheelOpen()) or self.inst.HUD:IsControllerInventoryOpen()
        end
        return true
    end
end

-- Hook: UsingMouse (wrap)
local function InstallUsingMouse(self)
    local old_UsingMouse = self.UsingMouse

    self.UsingMouse = function(self)
        -- If virtual cursor is active, pretend we're using mouse
        if VirtualCursor.IsCursorModeActive() then
            return true
        end
        return old_UsingMouse(self)
    end
end

-- Main Install function
function PlayerControllerHook.Install()
    G.AddComponentPostInit("playercontroller", function(self)
        Helpers.DebugPrint("Initializing Enhanced Controller")

        -- Load task configuration
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

        -- Install all method hooks
        InstallUpdateControllerTargets(self)
        InstallOnControl(self)
        InstallIsEnabled(self)
        InstallUsingMouse(self)

        Helpers.DebugPrint("PlayerController hooks installed")
    end)
end

return PlayerControllerHook
