-- Enhanced Controller - HUD Hook
-- Hooks PlayerHud for task config screen shortcut

local G = require("dst-controller/global")
local TaskConfigHook = require("dst-controller.screens.taskconfig-actions")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local ButtonHandler = require("dst-controller/executor/button-handler")

local PlayerHudHook = {}

local function InstallCookingMenu(self)
    if self.controls == nil or self.controls.left_root == nil then
        return
    end
    local CookingMenuHUD = require("dst-controller/widgets/cooking-menu-hud")
    local menu = self.controls.left_root:AddChild(CookingMenuHUD(self.owner))
    self.controls.enhanced_cooking_menu = menu

    local old_CloseCookbookScreen = self.CloseCookbookScreen
    self.OpenCookbookScreen = function(hud_self)
        if hud_self.cookbookscreen ~= nil then
            old_CloseCookbookScreen(hud_self)
        end
        menu:Toggle()
        return true
    end
    self.CloseCookbookScreen = function(hud_self)
        menu:Close()
        return old_CloseCookbookScreen(hud_self)
    end
end

-- Hook: PlayerHud:OnControl (wrap)
local function InstallOnControl(self)
    local old_OnControl = self.OnControl

    self.OnControl = function(hud_self, control, down)
        -- Check task config screen shortcut (LB+RB+Y)
        if TaskConfigHook.OnControl(hud_self, control, down) then
            return true
        end

        -- Check if this control is part of a button combination that can be handled
        -- If so, block it from default PlayerHud handling to avoid conflicts
        local _, need_handle = ButtonHandler.GetButtonCombinationActions(control, down)
        if need_handle then
            -- print("[PlayerHudHook] Blocking control: " .. control)
            return false
        end

        local cooking_menu = hud_self.controls and
            hud_self.controls.enhanced_cooking_menu
        if cooking_menu ~= nil and
            cooking_menu:HandleControl(control, down) then
            return true
        end

        -- 当有 examine_target 时，阻止 PlayerHud 的 InspectSelf 逻辑
        -- PlayerHud 的默认逻辑：如果 controller_target 为 nil，会调用 InspectSelf 打开玩家信息界面
        -- 但我们在 PlayerController 中已经处理了 examine_target 的情况，所以这里需要阻止
        if control == CONTROL_INSPECT and down then
            if self:IsVisible() and
                self:IsPlayerInfoPopUpOpen() and
                self.owner.components.playercontroller:IsEnabled() then
                self:TogglePlayerInfoPopup()
                return true
            elseif self.controls.votedialog:CheckControl(control, down) then
                return true
            elseif self.owner.components.playercontroller:GetControllerExamineTarget() ~= nil then
                return false
            end
        end

        return old_OnControl(hud_self, control, down)
    end
end


-- Install HUD hook
function PlayerHudHook.Install()
    -- Hook PlayerHud:OnControl for task config shortcut
    G.AddClassPostConstruct("screens/playerhud", function(self)
        InstallCookingMenu(self)
        InstallOnControl(self)
    end)
end

return PlayerHudHook
