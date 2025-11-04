-- Controls Widget Hook
-- Handles alternative target display
-- Note: cursor_widget is now created in TheFrontEnd hook

local G = require("dst-controller/global")

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

        -- Don't show hints if menus are open
        local menus_open = controls.inv.open or controls.commandwheel.isopen or
           controls.craftingmenu:IsCraftingOpen() or controls.spellwheel:IsOpen()

        -- ===== Handle alternative target hint =====
        if not alternative_target or menus_open then
            -- Hide alternative hint if no alternative target or menus open
            if controls.alternative_actionhint then
                controls.alternative_actionhint:Hide()
            end
        else
            -- Get alternative target action
            local _, alt_rmb = controller:GetSceneItemControllerAction(alternative_target)
            if not alt_rmb then
                if controls.alternative_actionhint then
                    controls.alternative_actionhint:Hide()
                end
            else
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
        
        local examine_target = controller.controller_examine_target ~= nil and controller.controller_examine_target:HasTag("inspectable") and controller.controller_examine_target or nil

        -- ===== Handle examine target hint =====
        if menus_open or not examine_target then
            -- Hide examine hint if no examine target or menus open
            if controls.examine_actionhint then
                controls.examine_actionhint:Hide()
            end
        else
            -- Create examine action hint widget if not exists
            if not controls.examine_actionhint then
                -- Use the same widget class as playeractionhint (FollowText)
                local FollowText = require("widgets/followtext")
                controls.examine_actionhint = controls:AddChild(FollowText(G.TALKINGFONT, 28))
            end

            -- Build hint text
            local controller_id = G.TheInput:GetControllerID()
            local hint_text = {}

            -- Add target name
            local adjective = examine_target:GetAdjective()
            table.insert(hint_text, adjective ~= nil and
                (adjective.." "..examine_target:GetDisplayName()) or
                examine_target:GetDisplayName())

            -- Add Y button action (Examine)
            table.insert(hint_text, G.TheInput:GetLocalizedControl(controller_id, G.CONTROL_INSPECT) ..
                " " .. G.STRINGS.ACTIONS.LOOKAT.GENERIC)

            -- Show the hint
            controls.examine_actionhint:Show()
            controls.examine_actionhint:SetTarget(examine_target)
            controls.examine_actionhint.text:SetString(table.concat(hint_text, "\n"))
        end
    end
end

-- Install Controls widget hook
function ControlsHook.Install()
    -- Hook into HUD for alternative target display
    G.AddClassPostConstruct("widgets/controls", function(self)
        -- Note: cursor_widget is now created in TheFrontEnd hook (overlayroot)
        -- to ensure it's always above all screens

        -- Hook OnUpdate for alternative target display
        HookOnUpdate(self)
    end)
end

return ControlsHook
