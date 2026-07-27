-- Modal player/favorite location window opened from MapScreen.

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")
local MapNavigation = require("dst-controller/utils/map-navigation")
local LocationPanel = require("dst-controller/widgets/location-panel")

local Screen = require("widgets/screen")
local ImageButton = require("widgets/imagebutton")
local TEMPLATES = require("widgets/redux/templates")

local LocationScreen = G.Class(Screen, function(
    self, map_screen, on_closed, ignore_opening_release)
    Screen._ctor(self, "EnhancedLocationScreen")
    self.map_screen = map_screen
    self.on_closed = on_closed
    self.closing = false
    self.ignore_opening_release = ignore_opening_release == true

    self.black = self:AddChild(ImageButton("images/global.xml", "square.tex"))
    self.black.image:SetVRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetHRegPoint(G.ANCHOR_MIDDLE)
    self.black.image:SetVAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetHAnchor(G.ANCHOR_MIDDLE)
    self.black.image:SetScaleMode(G.SCALEMODE_FILLSCREEN)
    self.black.image:SetTint(0, 0, 0, 0.55)
    self.black:SetOnClick(function() end)

    self.root = self:AddChild(TEMPLATES.ScreenRoot(
        "enhanced_location_screen_root"))
    self.panel = self.root:AddChild(LocationPanel(
        function() self:Close() end,
        function(position) self:Navigate(position) end))
    self.default_focus = self.panel:GetDefaultFocus()

    G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_open")
end)

function LocationScreen:Close()
    if self.closing then
        return
    end
    self.closing = true
    G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_close")
    G.TheFrontEnd:PopScreen(self)
end

function LocationScreen:Navigate(position)
    local x, z = position.x, position.z
    self:Close()
    MapNavigation.Start(x, z)
end

function LocationScreen:OnControl(control, down)
    if not down and self.ignore_opening_release then
        -- A physical trigger can emit more than one logical control release
        -- in the same input pass. Keep swallowing releases until that pass is
        -- complete instead of clearing the guard after the first event.
        if self.clear_opening_release_task == nil then
            self.clear_opening_release_task = self.inst:DoTaskInTime(0,
                function()
                    self.ignore_opening_release = false
                    self.clear_opening_release_task = nil
                end)
        end
        return true
    elseif Helpers.IsControlNamedButton(control, "LT") then
        if down then
            self.panel:CycleTab(-1)
        end
        return true
    elseif Helpers.IsControlNamedButton(control, "RT") then
        if down then
            self.panel:CycleTab(1)
        end
        return true
    elseif not down and control == G.CONTROL_CANCEL then
        self:Close()
        return true
    end
    if LocationScreen._base.OnControl(self, control, down) then
        return true
    end
    -- This is a modal screen: never allow unhandled input to reach MapScreen.
    return true
end

function LocationScreen:OnDestroy()
    if self.panel ~= nil then
        self.panel:Shutdown()
    end
    if self.on_closed ~= nil then
        self.on_closed(self)
        self.on_closed = nil
    end
    LocationScreen._base.OnDestroy(self)
end

return LocationScreen
