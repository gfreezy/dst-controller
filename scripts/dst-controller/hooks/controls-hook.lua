-- Controls Widget Hook
-- Injects cursor widget into HUD and handles alternative target display
-- Extracted from virtual-cursor-hook.lua

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local CursorWidget = require("dst-controller/virtual-cursor/cursor_widget")

local ControlsHook = {}

-- Hook OnUpdate to display alternative target hint
local function HookOnUpdate(self)
    local old_OnUpdate = self.OnUpdate

    self.OnUpdate = function(controls, dt)
        -- Call original OnUpdate first
        old_OnUpdate(controls, dt)

        -- Only handle in controller mode
        if not G.TheInput:ControllerAttached() then
            return
        end

        -- Check if we have an alternative target to display
        local controller = controls.owner and controls.owner.components.playercontroller
        if not controller then
            return
        end

        local alternative_target = controller.controller_alternative_target
        if not alternative_target then
            -- Hide alternative hint if no alternative target
            if controls.alternative_actionhint then
                controls.alternative_actionhint:Hide()
            end
            return
        end

        -- Don't show alternative hint if menus are open
        if controls.inv.open or controls.commandwheel.isopen or
           controls.craftingmenu:IsCraftingOpen() or controls.spellwheel:IsOpen() then
            if controls.alternative_actionhint then
                controls.alternative_actionhint:Hide()
            end
            return
        end

        -- Get alternative target action
        local _, alt_rmb = controller:GetSceneItemControllerAction(alternative_target)
        if not alt_rmb then
            if controls.alternative_actionhint then
                controls.alternative_actionhint:Hide()
            end
            return
        end

        -- Create alternative action hint widget if not exists
        if not controls.alternative_actionhint then
            -- Use the same widget class as playeractionhint (FollowText)
            local FollowText = require("widgets/followtext")
            controls.alternative_actionhint = controls:AddChild(FollowText(G.TALKINGFONT, 28))
        end

        -- Build hint text
        local controller_id = G.TheInput:GetControllerID()
        local hint_text = {}

        -- Add target name
        local adjective = alternative_target:GetAdjective()
        table.insert(hint_text, adjective ~= nil and
            (adjective.." "..alternative_target:GetDisplayName()) or
            alternative_target:GetDisplayName())

        -- Add B button action
        table.insert(hint_text, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_CONTROLLER_ALTACTION) ..
            " " .. alt_rmb:GetActionString())

        -- Show the hint
        controls.alternative_actionhint:Show()
        controls.alternative_actionhint:SetTarget(alternative_target)
        controls.alternative_actionhint.text:SetString(table.concat(hint_text, "\n"))
    end
end

-- Install Controls widget hook
function ControlsHook.Install()
    -- Hook into HUD to add cursor widget and alternative target display
    G.AddClassPostConstruct("widgets/controls", function(self)
        -- Create cursor widget and add to HUD
        local cursor_widget = self:AddChild(CursorWidget())
        cursor_widget:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
        cursor_widget:MoveToFront()  -- Ensure cursor is always on top

        -- Register widget with VirtualCursor core
        VirtualCursor.SetCursorWidget(cursor_widget)

        -- Store reference in playercontroller for updates
        if G.ThePlayer and G.ThePlayer.components.playercontroller then
            G.ThePlayer.components.playercontroller._cursor_widget = cursor_widget
        end

        -- Hook OnUpdate for alternative target display
        HookOnUpdate(self)
    end)
end

return ControlsHook
