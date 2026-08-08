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
local ClientPathfinder = require("dst-controller/utils/client_pathfinder")
local CraftingCoordinator = require("dst-controller/crafting/coordinator")
local CookingCoordinator = require("dst-controller/cooking/coordinator")

local PlayerControllerHook = {}

local function IsGameplayHudActive(player)
    local frontend = G.TheFrontEnd
    if player == nil or player.HUD == nil or frontend == nil or
        frontend.GetActiveScreen == nil then
        return false
    end
    return frontend:GetActiveScreen() == player.HUD
end

local function IsUsableControllerTarget(controller, target)
    return target ~= nil and
        target:IsValid() and
        not target:HasTag("INLIMBO") and
        not target:HasTag("NOCLICK") and
        target.entity:IsVisible() and
        G.CanEntitySeeTarget(controller.inst, target)
end

-- Hook: UpdateControllerTargets (override)
local function InstallUpdateControllerTargets(self)
    self.UpdateControllerTargets = function(self, dt)
        -- Delegate to target selection module
        TargetSelection.UpdateControllerTargets(self, dt)
    end

    self.GetControllerAlternativeTarget = function(self)
        local target = self.controller_alternative_target
        return IsUsableControllerTarget(self, target) and target or nil
    end

    self.GetControllerExamineTarget = function(self)
        local target = self.controller_examine_target
        return IsUsableControllerTarget(self, target) and target or nil
    end

    self.GetControllerItemUseTarget = function(self)
        local target = self.controller_item_use_target
        return IsUsableControllerTarget(self, target) and target or nil
    end
end

-- Hook: GetItemUseAction (wrap)
-- Inventory world-use actions use their own target pool instead of borrowing
-- the A-button target. Calls that pass an explicit target keep native behavior.
local function InstallGetItemUseAction(self)
    local old_GetItemUseAction = self.GetItemUseAction

    self.GetItemUseAction = function(self, active_item, target)
        if target ~= nil then
            return old_GetItemUseAction(self, active_item, target)
        end

        local cursor_item = self:GetCursorInventoryObject()
        local item_target = self:GetControllerItemUseTarget()
        if active_item ~= nil and
            active_item == cursor_item and
            active_item == self.controller_item_use_source and
            item_target ~= nil and
            not item_target:HasTag("INLIMBO") and
            not item_target:HasTag("NOCLICK") then
            -- Re-resolve the action at press/render time. If the target stopped
            -- accepting the item, fall back to the native shared-target path.
            local action = old_GetItemUseAction(self, active_item, item_target)
            if action ~= nil and action.target == item_target then
                return action
            end
        end

        return old_GetItemUseAction(self, active_item, nil)
    end
end

-- Hook: OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(self, control, down)
        -- print("[PlayerControllerHook] OnControl: " .. control, "down: " .. tostring(down))

        -- Any new user command takes ownership away from automatic crafting.
        -- Releases are ignored, so the control that started the task cannot
        -- immediately cancel it.
        CraftingCoordinator.OnUserControl(self.inst, control, down)
        CookingCoordinator.OnUserControl(self.inst, control, down)

        -- 检测用户主动移动，停止自动寻路
        -- 移动控制：左摇杆方向、WASD、点击地面移动
        if down and ClientPathfinder.IsActive() then
            local is_move_control = (
                control == G.CONTROL_MOVE_UP or
                control == G.CONTROL_MOVE_DOWN or
                control == G.CONTROL_MOVE_LEFT or
                control == G.CONTROL_MOVE_RIGHT or
                control == G.CONTROL_PRIMARY or      -- 左键点击
                control == G.CONTROL_SECONDARY or    -- 右键点击
                control == G.CONTROL_CONTROLLER_ACTION  -- 手柄 A 键
            )
            if is_move_control then
                ClientPathfinder.Stop()
            end
        end

        -- Try to handle as button combination
        local handled = false
        if IsGameplayHudActive(self.inst) then
            handled = ButtonHandler.HandleButtonCombination(
                self.inst,
                control,
                down,
                function(p, action_list)
                    ActionExecutor.ExecuteTaskActions(p, action_list, ACTIONS)
                end
            )
        end

        -- If handled, block default behavior
        if handled then
            -- print("[PlayerControllerHook] Handled button combination: " .. control)
            return true
        end

        -- Block LB/RB to prevent default camera rotation
        -- (Button combinations with LB/RB are handled by ButtonHandler)
        if Helpers.IsControlAnyOf(control, {"LB", "RB"}) then
            return true
        end

        -- Handle B button (CONTROL_CONTROLLER_ALTACTION) for alternative_target
        if control == G.CONTROL_CONTROLLER_ALTACTION then
            local alternative_target = self:GetControllerAlternativeTarget()
            if alternative_target ~= nil then
                -- 临时替换 controller_target 为 alternative_target
                local original_target = self.controller_target
                self.controller_target = alternative_target

                -- 调用原方法处理 B 键
                local result = old_OnControl(self, control, down)

                -- 恢复原来的 controller_target
                self.controller_target = original_target

                return result
            end
        end

        -- Handle Y button (CONTROL_INSPECT) for examine_target
        if control == G.CONTROL_INSPECT and down then
            local examine_target = self:GetControllerExamineTarget()
            if examine_target ~= nil then
                -- 临时替换 controller_target 为 examine_target
                local original_target = self.controller_target
                self.controller_target = examine_target

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

-- Hook: IsEnabled (wrap)
local function InstallIsEnabled(self)
    local old_IsEnabled = self.IsEnabled
    self.IsEnabled = function(self)
        local enabled, limited_gameplay = old_IsEnabled(self)
        if not enabled and self.inst.HUD ~= nil and self.inst.HUD:HasInputFocus() and
            self.inst.HUD.IsControllerInventoryOpen ~= nil and
            self.inst.HUD:IsControllerInventoryOpen() then
            return false, true
        end
        return enabled, limited_gameplay
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

-- NOTE: Building mode auto-activation has been removed.
-- Reason: VirtualCursor.AutoEnable() hooks TheInput:ControllerAttached() to return false,
-- which affects game logic that creates/destroys placer, causing a feedback loop.
-- Users can manually enable cursor mode with LB+RB+RT during building if needed.
local function InstallOnUpdate(self)
    -- No-op - building mode auto-activation disabled
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
        InstallGetItemUseAction(self)
        InstallOnControl(self)
        InstallIsEnabled(self)
        InstallUsingMouse(self)
        InstallDoControllerAttackButton(self)
        InstallOnUpdate(self)

        Helpers.DebugPrint("PlayerController hooks installed")
    end)
end

return PlayerControllerHook
