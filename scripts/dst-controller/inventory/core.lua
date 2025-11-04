local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")

-- Original Inv:OnControl implementation from scripts-raw/widgets/inventorybar.lua
-- Lines 778-865
-- This is a reference copy for understanding the original behavior

local InventoryBarHook = {}

function InventoryBarHook.OnUpdate(self, dt)
    if self.autopaused then
        return
    end
    self:UpdatePosition()

    self.hint_update_check = self.hint_update_check - dt
    if 0 > self.hint_update_check then
        if #self.inv <= 0 or not G.TheInput:ControllerAttached() then
            self.openhint:Hide()
        else
            self.openhint:Show()
            self.openhint:SetString(G.TheInput:GetLocalizedControl(G.TheInput:GetControllerID(), G.CONTROL_OPEN_INVENTORY))
        end
        self.hint_update_check = G.HINT_UPDATE_INTERVAL
    end

    if not self.owner.HUD.shown or self.owner.HUD ~= TheFrontEnd:GetActiveScreen() then
        return
    end

    if self.rebuild_pending then
        self:Rebuild()
        self:Refresh()
    end

	if self.owner.HUD:IsCraftingOpen() or self.owner.HUD:IsSpellWheelOpen() then
        self.actionstring:Hide()
		return
	end

    --V2C: Don't set pause in multiplayer, all it does is change the
    --     audio settings, which we don't want to do now
    --if self.open and TheInput:ControllerAttached() then
    --    SetPause(true, "inv")
    --end

    if not self.open and self.actionstring and self.actionstringtime and self.actionstringtime > 0 then
        self.actionstringtime = self.actionstringtime - dt
        if self.actionstringtime <= 0 then
            self.actionstring:Hide()
        end
    end

    if self.repeat_time > 0 then
        self.repeat_time = self.repeat_time - dt
    end

    if self.active_slot ~= nil and not self.active_slot.inst:IsValid() then
        self:SelectDefaultSlot()

        if self.cursor ~= nil then
            self.cursor:Kill()
            self.cursor = nil
        end
    end

    self:UpdateCursor()

    if self.shown and not VirtualCursor.IsCursorModeActive() then
        --this is intentionally unaware of focus
        if self.repeat_time <= 0 then
            self.reps = self.reps and (self.reps + 1) or 1

			if G.TheInput:IsControlPressed(G.VIRTUAL_CONTROL_INV_LEFT) then
				self:RefreshRepeatDelay(G.VIRTUAL_CONTROL_INV_LEFT)
				self:CursorLeft()
				return
			elseif G.TheInput:IsControlPressed(G.VIRTUAL_CONTROL_INV_RIGHT) then
				self:RefreshRepeatDelay(G.VIRTUAL_CONTROL_INV_RIGHT)
				self:CursorRight()
				return
			elseif G.TheInput:IsControlPressed(G.VIRTUAL_CONTROL_INV_UP) then
				self:RefreshRepeatDelay(G.VIRTUAL_CONTROL_INV_UP)
				self:CursorUp()
				return
			elseif G.TheInput:IsControlPressed(G.VIRTUAL_CONTROL_INV_DOWN) then
				self:RefreshRepeatDelay(G.VIRTUAL_CONTROL_INV_DOWN)
				self:CursorDown()
				return
			end

			self.repeat_time = 0
			self.reps = 0
        end
    end
end

return InventoryBarHook