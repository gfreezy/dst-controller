-- Half-screen cooking list that remains part of PlayerHud. It intentionally
-- does not take global input focus, enable crafting navigation, or autopoause.

local G = require("dst-controller/global")
local Coordinator = require("dst-controller/cooking/coordinator")
local FocusStick = require("dst-controller/utils/focus-stick")
local MenuData = require("dst-controller/cooking/menu-data")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local L = require("dst-controller/localization").L

local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local cooking = require("cooking")

local PANEL_WIDTH = 500
local PANEL_HEIGHT = 600
local COLUMNS = 4
local ROWS = 5
local PAGE_SIZE = COLUMNS * ROWS
local CELL_SIZE = 72
local CELL_SPACING = 12
local CELL_TEXTURE_SIZE = 128

local function FoodStats(recipe)
    return L("COOKING_MENU_STATS",
        tostring(recipe.health or 0),
        tostring(recipe.hunger or 0),
        tostring(recipe.sanity or 0))
end

local CookingMenuHUD = G.Class(Widget, function(self, owner)
    Widget._ctor(self, "EnhancedCookingMenuHUD")
    self.owner = owner
    self.is_open = false
    self.navigation_active = false
    self.selected_index = 1
    self.page = 1
    self.products = {}
    self.right_stick = {}

    self.closed_pos = G.Vector3(0, 0, 0)
    self.opened_pos = G.Vector3(530, 0, 0)
    self.ui_root = self:AddChild(Widget("enhanced_cooking_menu_root"))
    self.ui_root:SetPosition(self.closed_pos:Get())

    self.panel = self.ui_root:AddChild(Widget("enhanced_cooking_menu_panel"))
    self.panel:SetPosition(-255, 0)

    local atlas = G.resolvefilepath ~= nil and G.CRAFTING_ATLAS ~= nil and
        G.resolvefilepath(G.CRAFTING_ATLAS) or "images/crafting_menu.xml"
    local fill = self.panel:AddChild(Image(atlas, "backing.tex"))
    fill:ScaleToSize(PANEL_WIDTH + 10, PANEL_HEIGHT + 18)
    fill:SetTint(1, 1, 1, 0.78)
    fill:SetClickable(false)

    local left = self.panel:AddChild(Image(atlas, "side.tex"))
    left:SetPosition(-PANEL_WIDTH / 2 - 8, 1)
    left:ScaleToSize(-26, -(PANEL_HEIGHT - 20))
    left:SetClickable(false)
    local right = self.panel:AddChild(Image(atlas, "side.tex"))
    right:SetPosition(PANEL_WIDTH / 2 + 8, 1)
    right:ScaleToSize(26, PANEL_HEIGHT - 20)
    right:SetClickable(false)
    local top = self.panel:AddChild(Image(atlas, "top.tex"))
    top:SetPosition(0, PANEL_HEIGHT / 2 + 10)
    top:ScaleToSize(534, 38)
    top:SetClickable(false)
    local bottom = self.panel:AddChild(Image(atlas, "bottom.tex"))
    bottom:SetPosition(0, -PANEL_HEIGHT / 2 - 8)
    bottom:ScaleToSize(534, 38)
    bottom:SetClickable(false)

    self.title = self.panel:AddChild(Text(
        G.HEADERFONT, 34, L("COOKING_MENU_TITLE"), G.UICOLOURS.GOLD))
    self.title:SetPosition(0, 260)

    self.cells = {}
    local grid_width = COLUMNS * CELL_SIZE + (COLUMNS - 1) * CELL_SPACING
    local first_x = -grid_width / 2 + CELL_SIZE / 2
    local first_y = 190
    local cell_scale = CELL_SIZE / CELL_TEXTURE_SIZE
    for slot = 1, PAGE_SIZE do
        local row = math.floor((slot - 1) / COLUMNS)
        local column = (slot - 1) % COLUMNS
        local button = self.panel:AddChild(ImageButton(
            "images/quagmire_recipebook.xml",
            "cookbook_known.tex",
            "cookbook_known_selected.tex",
            "cookbook_unknown.tex",
            nil,
            "cookbook_known_selected.tex"))
        button:SetPosition(
            first_x + column * (CELL_SIZE + CELL_SPACING),
            first_y - row * (CELL_SIZE + CELL_SPACING))
        button:SetNormalScale(cell_scale, cell_scale)
        button:SetFocusScale(cell_scale + 0.04, cell_scale + 0.04)
        button.AllowOnControlWhenSelected = true

        local icon = button.image:AddChild(Image(
            "images/quagmire_recipebook.xml", "cookbook_missing.tex"))
        icon:ScaleToSize(CELL_TEXTURE_SIZE + 28, CELL_TEXTURE_SIZE + 28)
        icon:SetClickable(false)
        local slot_index = slot
        button:SetOnClick(function()
            local absolute_index = (self.page - 1) * PAGE_SIZE + slot_index
            if self.products[absolute_index] ~= nil then
                self:SetSelectedIndex(absolute_index)
            end
        end)
        self.cells[slot] = { button = button, icon = icon }
    end

    self.selected_name = self.panel:AddChild(Text(
        G.HEADERFONT, 30, "", G.UICOLOURS.GOLD))
    self.selected_name:SetPosition(0, -225)
    self.selected_stats = self.panel:AddChild(Text(
        G.BODYTEXTFONT, 22, "", G.UICOLOURS.GOLD_UNIMPORTANT))
    self.selected_stats:SetPosition(0, -255)

    self.page_text = self.panel:AddChild(Text(
        G.BODYTEXTFONT, 20, "", G.UICOLOURS.GOLD_UNIMPORTANT))
    self.page_text:SetPosition(190, 255)

    self.cook_button = self.panel:AddChild(TEMPLATES.StandardButton(function()
        self:StartSelected()
    end, L("SEARCH_AND_COOK"), { 180, 42 }))
    self.cook_button:SetPosition(120, -290)
    self.close_button = self.panel:AddChild(TEMPLATES.StandardButton(function()
        self:Close()
    end, L("BUTTON_CLOSE"), { 100, 42 }))
    self.close_button:SetPosition(-110, -290)

    self.hint = self:AddChild(Text(
        G.BODYTEXTFONT, 24, L("COOKING_MENU_HINT"),
        G.UICOLOURS.GOLD_UNIMPORTANT))
    self.hint:SetPosition(275, -338)

    fill:MoveToBack()
    self:StartUpdating()
    self:Hide()
end)

function CookingMenuHUD:IsOpen()
    return self.is_open
end

function CookingMenuHUD:RebuildProducts()
    self.products = MenuData.Build(cooking, G.STRINGS and G.STRINGS.NAMES)
    if #self.products == 0 then
        self.selected_index = 0
    else
        self.selected_index = math.max(1,
            math.min(self.selected_index, #self.products))
    end
    self.page = math.max(1, math.ceil(math.max(1, self.selected_index) / PAGE_SIZE))
    self:RefreshPage()
end

function CookingMenuHUD:RefreshPage()
    for slot, cell in ipairs(self.cells) do
        local absolute_index = (self.page - 1) * PAGE_SIZE + slot
        local data = self.products[absolute_index]
        if data == nil then
            cell.button:Hide()
        else
            cell.button:Show()
            cell.button:SetTooltip(data.name)
            local image_name = data.recipe_def.cookbook_tex or
                (data.prefab .. ".tex")
            local atlas = data.recipe_def.cookbook_atlas or
                (G.GetInventoryItemAtlas ~= nil and
                    G.GetInventoryItemAtlas(image_name, true))
            cell.icon:SetTexture(
                atlas or "images/quagmire_recipebook.xml",
                atlas ~= nil and image_name or "cookbook_missing.tex")
            if absolute_index == self.selected_index then
                cell.button:Select()
            else
                cell.button:Unselect()
            end
        end
    end

    local selected = self.products[self.selected_index]
    if selected ~= nil then
        self.selected_name:SetString(selected.name)
        self.selected_stats:SetString(FoodStats(selected.recipe_def))
        self.cook_button:Enable()
    else
        self.selected_name:SetString(L("COOKING_MENU_EMPTY"))
        self.selected_stats:SetString("")
        self.cook_button:Disable()
    end
    local pages = math.max(1, math.ceil(#self.products / PAGE_SIZE))
    self.page_text:SetString(L("COOKING_MENU_PAGE", self.page, pages))
end

function CookingMenuHUD:SetSelectedIndex(index)
    if #self.products == 0 then
        return
    end
    self.selected_index = math.max(1, math.min(index, #self.products))
    self.page = math.ceil(self.selected_index / PAGE_SIZE)
    self:RefreshPage()
    if G.TheFrontEnd ~= nil then
        G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_mouseover")
    end
end

function CookingMenuHUD:Navigate(direction)
    if #self.products == 0 then
        return
    end
    local index = math.max(1, self.selected_index)
    if direction == "left" then
        index = index - 1
    elseif direction == "right" then
        index = index + 1
    elseif direction == "up" then
        index = index - COLUMNS
    elseif direction == "down" then
        index = index + COLUMNS
    end
    self:SetSelectedIndex(index)
end

function CookingMenuHUD:StartSelected()
    local selected = self.products[self.selected_index]
    local player = self.owner
    if selected == nil or player == nil or not player:IsValid() then
        return
    end
    local request = {
        product = selected.prefab,
        recipes = {},
        dynamic_recipes = true,
        cooker_prefabs = selected.cooker_prefabs,
    }
    self:Close()
    player:DoTaskInTime(0, function()
        if player:IsValid() then
            Coordinator.Start(player, request)
        end
    end)
end

function CookingMenuHUD:Open()
    if self.is_open then
        return
    end
    local hud = self.owner and self.owner.HUD
    if hud ~= nil then
        if hud.IsCraftingOpen ~= nil and hud:IsCraftingOpen() then
            hud:CloseCrafting()
        end
        if hud.IsControllerInventoryOpen ~= nil and
            hud:IsControllerInventoryOpen() then
            hud:CloseControllerInventory()
        end
    end
    self:RebuildProducts()
    self.is_open = true
    self.navigation_active = G.TheInput:ControllerAttached()
    FocusStick.Reset(self.right_stick)
    self:Show()
    self.ui_root:Enable()
    self.ui_root:SetPosition(self.closed_pos:Get())
    self.ui_root:MoveTo(self.closed_pos, self.opened_pos, 0.25)
    G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_open")
end

function CookingMenuHUD:Close()
    if not self.is_open then
        return
    end
    self.is_open = false
    self.navigation_active = false
    FocusStick.Reset(self.right_stick)
    self.ui_root:Disable()
    self.ui_root:MoveTo(self.ui_root:GetPosition(), self.closed_pos, 0.25,
        function()
            if not self.is_open then
                self:Hide()
            end
        end)
    G.TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/craft_close")
end

function CookingMenuHUD:Toggle()
    if self.is_open then
        self:Close()
    else
        self:Open()
    end
end

function CookingMenuHUD:HandleControl(control, down)
    if not self.is_open or not self.navigation_active then
        return false
    elseif control == G.CONTROL_ACCEPT or
        control == G.CONTROL_CONTROLLER_ACTION then
        if down then
            self:StartSelected()
        end
        return true
    elseif control == G.CONTROL_CANCEL or
        control == G.CONTROL_CONTROLLER_ALTACTION then
        if down then
            self:Close()
        end
        return true
    end
    return false
end

function CookingMenuHUD:OnUpdate(dt)
    if not self.is_open or not G.TheInput:ControllerAttached() or
        VirtualCursor.IsCursorModeActive() then
        FocusStick.Reset(self.right_stick)
        return
    end
    local x = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_RIGHT) -
        G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_LEFT)
    local y = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_UP) -
        G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_DOWN)
    local direction = FocusStick.Update(self.right_stick, dt, x, y)
    if direction ~= nil then
        self.navigation_active = true
        self:Navigate(direction)
    end
end

return CookingMenuHUD
