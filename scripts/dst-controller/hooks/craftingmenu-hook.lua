-- Enhanced Controller - CraftingMenu Hook
-- Hides the bottom layer that covers inventory bar and blocks right stick in virtual cursor mode

local G = require("dst-controller/global")

local CraftingMenuHook = {}

-- Install CraftingMenu hook
function CraftingMenuHook.Install()
    -- Force focus back to inventory before opening craftmenu
    -- This ensures consistent behavior regardless of whether pinbar has focus
    G.AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(hud)
        local old_Open = hud.Open

        hud.Open = function(self, search)
            -- If pinbar has focus in controller mode, move focus back to inventory first
            -- This makes behavior consistent with when pinbar doesn't have focus
            if G.TheInput:ControllerAttached() and self.pinbar and self.pinbar.focus then
                -- Access inventorybar through owner.HUD.controls.inv
                local inv = self.owner and self.owner.HUD and self.owner.HUD.controls and self.owner.HUD.controls.inv
                if inv and inv.SelectDefaultSlot then
                    inv:SelectDefaultSlot()
                end
            end

            -- Call original Open
            return old_Open(self, search)
        end

        print("[CraftingMenuHook] Installed CraftingMenuHUD:Open hook (restore inventory focus)")
    end)

    -- Hide pinbar help text by returning empty string
    G.AddClassPostConstruct("widgets/redux/craftingmenu_pinslot", function(self)

        -- remove pinslot black help message on the bottom of screen
        local Refresh_Old = self.Refresh
        self.Refresh = function (self, ...)
            Refresh_Old(self, ...)
            self.craft_button.GetHelpText = function (_self, ...) return "" end
        end

    end)
end

return CraftingMenuHook
