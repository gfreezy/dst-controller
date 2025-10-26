-- Enhanced Controller - Inventorybar Hook
-- Hooks inventorybar widget to customize inventory behavior
--
-- Strategy:
--   1. Remove "shouldautopausecontrollerinventory" tag from player (done in modmain.lua)
--      This prevents autopause in OnUpdate without modifying it
--   2. Override OnControl to allow movement controls to pass through
--   3. Override OpenControllerInventory to remove TheFrontEnd:LockFocus call

local G = require("global")
local Helpers = require("utils/helpers")
local Original = require("hooks/original/core")

local InventorybarHook = {}

-- Install inventorybar hook
function InventorybarHook.Install()
    G.AddClassPostConstruct("widgets/inventorybar", function(self)
        -- Save original OnControl
        -- local OldOnControl = self.OnControl

        -- -- Override OnControl to allow movement while inventory is open
        -- function self:OnControl(control, down)
        --     -- If inventory is open, allow movement controls to pass through
        --     if self.open then
        --         if control == G.CONTROL_MOVE_UP or
        --            control == G.CONTROL_MOVE_DOWN or
        --            control == G.CONTROL_MOVE_LEFT or
        --            control == G.CONTROL_MOVE_RIGHT then
        --             return false  -- Don't handle, let player controller process it
        --         end
        --     end

        --     -- Call original implementation for all other controls
        --     return OldOnControl(self, control, down)
        -- end

        function self:OnUpdate(dt)
            -- Stop atuopause behavior by skipping the relevant code
            return Original.OnUpdate(self, dt)
        end

        function self:OpenControllerInventory()
            -- if self.owner.sg ~= nil then
            --     self.owner.sg:RemoveStateTag("shouldautopausecontrollerinventory")
            --     self.owner:RemoveTag("shouldautopausecontrollerinventory")
            -- end

            if not self.open then
                self.open = true
                self.force_single_drop = false --reset the flag

                if self.pin_nav then
                    self:CursorRight()
                end

                self:UpdateCursor()
                self:ScaleTo(self.base_scale,self.selected_scale,.2)

                for _, v in pairs(self.owner.HUD.controls.containers) do
                    v:ScaleTo(self.base_scale,self.selected_scale,.2)
                end

                self:SetFocus()
            end
        end

        Helpers.DebugPrint("Inventorybar hook installed")
    end)
end

return InventorybarHook
