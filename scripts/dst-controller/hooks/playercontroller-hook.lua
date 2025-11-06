-- PlayerController Hook
-- Consolidates ALL playercontroller component hooks in one place
-- Delegates to feature-specific modules for actual logic

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local ButtonHandler = require("dst-controller/executor/button-handler")
local ActionExecutor = require("dst-controller/executor/action-executor")
local ConfigManager = require("dst-controller/utils/config_manager")
local ACTIONS = require("dst-controller/actions/init")
local TargetSelection = require("dst-controller/target-selection/core")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local debugtools = require("debugtools")

local PlayerControllerHook = {}

-- Hook: UpdateControllerTargets (override)
local function InstallUpdateControllerTargets(self)
    self.UpdateControllerTargets = function(self, dt)
        -- Delegate to target selection module
        TargetSelection.UpdateControllerTargets(self, dt)
    end

    self.GetControllerAlternativeTarget = function(self)
        return self.controller_alternative_target
    end

    self.GetControllerExamineTarget = function(self)
        return self.controller_examine_target
    end
end

-- Hook: OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(self, control, down)
        -- print("[PlayerControllerHook] OnControl: " .. control, "down: " .. tostring(down))
        
        -- Try to handle as button combination
        local handled = ButtonHandler.HandleButtonCombination(
            self.inst,
            control,
            down,
            function(p, action_list)
                print("[PlayerControllerHook] Handling button combination: " .. control, "action_list: " .. table.inspect(action_list))
                ActionExecutor.ExecuteTaskActions(p, action_list, ACTIONS)
            end
        )

        -- If handled, block default behavior
        if handled then
            print("[PlayerControllerHook] Handled button combination: " .. control)
            return true
        end

        -- Block LB/RB to prevent default camera rotation
        -- (Button combinations with LB/RB are handled by ButtonHandler)
        if Helpers.IsControlAnyOf(control, {"LB", "RB"}) then
            return true
        end

        -- Handle B button (CONTROL_CONTROLLER_ALTACTION) for alternative_target
        if control == G.CONTROL_CONTROLLER_ALTACTION then
            if self.controller_alternative_target ~= nil then
                -- 临时替换 controller_target 为 alternative_target
                local original_target = self.controller_target
                self.controller_target = self.controller_alternative_target

                -- 调用原方法处理 B 键
                local result = old_OnControl(self, control, down)

                -- 恢复原来的 controller_target
                self.controller_target = original_target

                return result
            end
        end

        -- Handle Y button (CONTROL_INSPECT) for examine_target
        if control == G.CONTROL_INSPECT and down then
            if self.controller_examine_target ~= nil then
                -- 临时替换 controller_target 为 examine_target
                local original_target = self.controller_target
                self.controller_target = self.controller_examine_target

                -- 调用原方法处理 Y 键
                local result = old_OnControl(self, control, down)

                -- 恢复原来的 controller_target
                self.controller_target = original_target

                return result
            end
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

-- Hook: DoControllerAttackButton (wrap)
local function InstallDoControllerAttackButton(self)
    local old_DoControllerAttackButton = self.DoControllerAttackButton

    self.DoControllerAttackButton = function(self, target)
        -- Check if air attack is disabled
        local settings = ConfigManager.GetRuntimeSettings()
        if settings and settings.allow_air_attack == false then
            -- If air attack is disabled and there's no target, don't attack
            if target == nil and self.controller_attack_target == nil then
                Helpers.DebugPrint("[DoControllerAttackButton] Air attack disabled, no target - blocking attack")
                return
            end
        end

        -- Call original method
        return old_DoControllerAttackButton(self, target)
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
        InstallDoControllerAttackButton(self)

        Helpers.DebugPrint("PlayerController hooks installed")
    end)
end

return PlayerControllerHook
