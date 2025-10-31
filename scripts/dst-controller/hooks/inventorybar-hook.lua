-- Enhanced Controller - Inventorybar Hook
-- Hooks inventorybar widget to customize inventory behavior
--
-- Strategy:
--   1. Remove "shouldautopausecontrollerinventory" tag from player (done in modmain.lua)
--      This prevents autopause in OnUpdate without modifying it
--   2. Override OnControl to allow movement controls to pass through

local G = require("dst-controller/global")

local InventorybarHook = {}

-- Install inventorybar hook
function InventorybarHook.Install()
    G.AddClassPostConstruct("widgets/inventorybar", function(self)
        function self:OpenControllerInventory()
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
    end)
end

return InventorybarHook
