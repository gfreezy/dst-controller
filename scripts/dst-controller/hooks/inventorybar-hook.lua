-- Enhanced Controller - Inventorybar Hook
-- Hooks inventorybar widget to customize inventory behavior
--
-- Strategy:
--   1. Remove "shouldautopausecontrollerinventory" tag from player (done in modmain.lua)
--      This prevents autopause in OnUpdate without modifying it
--   2. Override OnControl to allow movement controls to pass through

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

local InventorybarHook = {}

-- Install inventorybar hook
function InventorybarHook.Install()
    G.AddClassPostConstruct("widgets/inventorybar", function(self)
        -- Save original OnControl
        local old_OnControl = self.OnControl

        function self:OnControl(control, down)
            -- If virtual cursor is active, let HUD work normally (mouse mode behavior)
            if VirtualCursor.IsCursorModeActive() then
                return false
            end
            return old_OnControl(self, control, down)
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
                G.TheFrontEnd:LockFocus(true)
            end
        end

        Helpers.DebugPrint("Inventorybar hook installed")
    end)
end

return InventorybarHook
