-- Enhanced Controller - Player and favorite locations panel for MapScreen

local G = require("dst-controller/global")
local PlayerService = require("dst-controller/locations/player-service")
local FavoritesStore = require("dst-controller/locations/favorites-store")
local MapNavigation = require("dst-controller/utils/map-navigation")
local L = require("dst-controller/localization").L

local Widget = require("widgets/widget")
local Text = require("widgets/text")
local TEMPLATES = require("widgets/redux/templates")
local InputDialogScreen = require("screens/redux/inputdialog")

local PANEL_WIDTH = 440
local PANEL_HEIGHT = 590
local ROW_COUNT = 7

local LocationPanel = G.Class(Widget, function(self)
    Widget._ctor(self, "EnhancedLocationPanel")
    self.active_tab = "players"
    self.player_page = 1
    self.favorite_page = 1
    self.rows_data = {}

    self:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
    self:SetHAnchor(G.ANCHOR_LEFT)
    self:SetVAnchor(G.ANCHOR_MIDDLE)
    self:SetPosition(PANEL_WIDTH / 2 + 18, 0)

    self.frame = self:AddChild(TEMPLATES.RectangleWindow(
        PANEL_WIDTH, PANEL_HEIGHT, L("LOCATION_PANEL_TITLE")))
    self.frame:SetScale(1, 1)
    self.frame:MoveToBack()

    self.players_tab = self:AddChild(TEMPLATES.StandardButton(function()
        self:SetTab("players")
    end, L("LOCATION_TAB_PLAYERS"), { 190, 42 }))
    self.players_tab:SetPosition(-100, 235)
    self.favorites_tab = self:AddChild(TEMPLATES.StandardButton(function()
        self:SetTab("favorites")
    end, L("LOCATION_TAB_FAVORITES"), { 190, 42 }))
    self.favorites_tab:SetPosition(100, 235)

    self.action_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:RunPrimaryAction()
    end, "", { 260, 42 }))
    self.action_button:SetPosition(0, 185)

    self.rows = {}
    local first_y = 125
    for index = 1, ROW_COUNT do
        local y = first_y - (index - 1) * 55
        local row = {
            main = self:AddChild(TEMPLATES.StandardButton(function()
                self:ActivateRow(index)
            end, "", { 270, 46 })),
            secondary = self:AddChild(TEMPLATES.StandardButton(function()
                self:SecondaryRowAction(index)
            end, "", { 70, 42 })),
            tertiary = self:AddChild(TEMPLATES.StandardButton(function()
                self:TertiaryRowAction(index)
            end, "", { 70, 42 })),
        }
        row.main:SetPosition(-72, y)
        row.main:SetTextSize(18)
        row.secondary:SetPosition(105, y)
        row.secondary:SetTextSize(17)
        row.tertiary:SetPosition(180, y)
        row.tertiary:SetTextSize(17)
        self.rows[index] = row
    end

    self.empty_text = self:AddChild(Text(
        G.BODYTEXTFONT, 22, "", G.UICOLOURS.GOLD_UNIMPORTANT))
    self.empty_text:SetPosition(0, -10)

    self.previous_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:ChangePage(-1)
    end, "<", { 55, 38 }))
    self.previous_button:SetPosition(-100, -265)
    self.page_text = self:AddChild(Text(
        G.BODYTEXTFONT, 20, "", G.UICOLOURS.GOLD_UNIMPORTANT))
    self.page_text:SetPosition(0, -265)
    self.next_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:ChangePage(1)
    end, ">", { 55, 38 }))
    self.next_button:SetPosition(100, -265)

    self.remove_player_subscription = PlayerService.Subscribe(function()
        self:Refresh()
    end)
    self.remove_favorite_subscription = FavoritesStore.Subscribe(function()
        self:Refresh()
    end)
    FavoritesStore.Load(function()
        if self.inst:IsValid() then
            self:Refresh()
        end
    end)
    self:SetTab("players")
end)

local function PositionLabel(position)
    return string.format("(%.1f, %.1f)", position.x, position.z)
end

local function StatusLabel(status)
    local keys = {
        not_queried = "LOCATION_STATUS_NOT_QUERIED",
        querying = "LOCATION_STATUS_QUERYING",
        located = "LOCATION_STATUS_LOCATED",
        other_shard = "LOCATION_STATUS_OTHER_SHARD",
        unavailable = "LOCATION_STATUS_UNAVAILABLE",
    }
    return L(keys[status] or "LOCATION_STATUS_NOT_QUERIED")
end

local function PromptName(title, initial_value, on_confirm)
    local dialog
    local function Confirm()
        local value = dialog:GetActualString():match("^%s*(.-)%s*$") or ""
        if value ~= "" then
            G.TheFrontEnd:PopScreen(dialog)
            on_confirm(value)
        end
    end
    dialog = InputDialogScreen(title, {
        { text = L("BUTTON_CONFIRM"), cb = Confirm },
        {
            text = L("BUTTON_CANCEL"),
            cb = function() G.TheFrontEnd:PopScreen(dialog) end,
        },
    }, true)
    dialog:OverrideText(initial_value or "")
    dialog.edit_text:SetTextLengthLimit(40)
    dialog.edit_text.OnTextEntered = Confirm
    G.TheFrontEnd:PushScreen(dialog)
    dialog.edit_text:OnControl(G.CONTROL_ACCEPT, false)
end

function LocationPanel:SetTab(tab)
    self.active_tab = tab
    if tab == "players" then
        self.players_tab:Select()
        self.favorites_tab:Unselect()
    else
        self.players_tab:Unselect()
        self.favorites_tab:Select()
    end
    self:Refresh()
end

function LocationPanel:RunPrimaryAction()
    if self.active_tab == "players" then
        PlayerService.QueryAll()
    else
        local count = #FavoritesStore.GetCurrentShard() + 1
        PromptName(L("LOCATION_NAME_PROMPT"),
            L("LOCATION_DEFAULT_NAME", count), function(name)
                FavoritesStore.AddCurrent(name)
            end)
    end
end

function LocationPanel:Refresh()
    if self.active_tab == "players" then
        self.action_button:SetText(L("LOCATION_QUERY_ALL"))
        self.action_button:Enable()
        self.rows_data = PlayerService.GetPlayers()
    else
        self.action_button:SetText(L("LOCATION_ADD_CURRENT"))
        if FavoritesStore.IsLoaded() then
            self.action_button:Enable()
        else
            self.action_button:Disable()
        end
        self.rows_data = FavoritesStore.GetCurrentWorld()
    end

    local current_page = self.active_tab == "players" and
        self.player_page or self.favorite_page
    local page_count = math.max(1, math.ceil(#self.rows_data / ROW_COUNT))
    current_page = math.max(1, math.min(current_page, page_count))
    if self.active_tab == "players" then
        self.player_page = current_page
    else
        self.favorite_page = current_page
    end

    local first_index = (current_page - 1) * ROW_COUNT + 1
    for slot, row in ipairs(self.rows) do
        local data = self.rows_data[first_index + slot - 1]
        if data == nil then
            row.main:Hide()
            row.secondary:Hide()
            row.tertiary:Hide()
        else
            row.main:Show()
            row.secondary:Show()
            if self.active_tab == "players" then
                local position = data.position
                local detail = position ~= nil and
                    (position.current_shard and PositionLabel(position) or
                        (position.world_type or position.shard_id)) or
                    StatusLabel(data.status)
                local label = string.format("%s  %s", data.name, detail)
                row.main:SetText(label)
                row.main.text:SetTruncatedString(label, 250, 32, true)
                row.main:SetTooltip(label .. "\n" .. data.userid)
                if position ~= nil and position.current_shard then
                    row.main:Enable()
                else
                    row.main:Disable()
                end
                row.secondary:SetText(data.status == "not_queried" and
                    L("LOCATION_QUERY") or L("LOCATION_REFRESH"))
                row.secondary:Enable()
                row.tertiary:Hide()
            else
                local detail = data.current_shard and PositionLabel(data) or
                    (data.world_type or data.shard_id)
                local label = string.format("%s  %s", data.name, detail)
                row.main:SetText(label)
                row.main.text:SetTruncatedString(label, 250, 32, true)
                row.main:SetTooltip(label .. "\n" .. data.shard_id)
                if data.current_shard then
                    row.main:Enable()
                else
                    row.main:Disable()
                end
                row.secondary:SetText(L("BUTTON_EDIT"))
                row.tertiary:SetText(L("BUTTON_DELETE"))
                row.secondary:Enable()
                row.tertiary:Enable()
                row.tertiary:Show()
            end
        end
    end

    if #self.rows_data == 0 then
        self.empty_text:SetString(self.active_tab == "players" and
            L("LOCATION_NO_PLAYERS") or L("LOCATION_NO_FAVORITES"))
        self.empty_text:Show()
    else
        self.empty_text:Hide()
    end
    self.page_text:SetString(string.format("%d / %d", current_page, page_count))
    if current_page > 1 then self.previous_button:Enable() else self.previous_button:Disable() end
    if current_page < page_count then self.next_button:Enable() else self.next_button:Disable() end
end

function LocationPanel:GetRowData(slot)
    local page = self.active_tab == "players" and
        self.player_page or self.favorite_page
    return self.rows_data[(page - 1) * ROW_COUNT + slot]
end

function LocationPanel:ActivateRow(slot)
    local data = self:GetRowData(slot)
    local position = data ~= nil and
        (self.active_tab == "players" and data.position or data) or nil
    if position ~= nil and position.current_shard then
        MapNavigation.Start(position.x, position.z)
    end
end

function LocationPanel:SecondaryRowAction(slot)
    local data = self:GetRowData(slot)
    if data == nil then
        return
    end
    if self.active_tab == "players" then
        PlayerService.QueryPlayer(data.userid, data.name)
    else
        PromptName(L("LOCATION_RENAME_PROMPT"), data.name, function(name)
            FavoritesStore.Rename(data.id, name)
        end)
    end
end

function LocationPanel:TertiaryRowAction(slot)
    local data = self:GetRowData(slot)
    if self.active_tab == "favorites" and data ~= nil then
        FavoritesStore.Remove(data.id)
    end
end

function LocationPanel:ChangePage(delta)
    if self.active_tab == "players" then
        self.player_page = self.player_page + delta
    else
        self.favorite_page = self.favorite_page + delta
    end
    self:Refresh()
end

function LocationPanel:IsPointerOver()
    if not self:IsVisible() or G.TheSim == nil then
        return false
    end
    local x, y = G.TheSim:GetPosition()
    local _, height = G.TheSim:GetScreenSize()
    return x <= PANEL_WIDTH + 36 and
        y >= (height - PANEL_HEIGHT) / 2 and
        y <= (height + PANEL_HEIGHT) / 2
end

function LocationPanel:Shutdown()
    if self.remove_player_subscription ~= nil then
        self.remove_player_subscription()
        self.remove_player_subscription = nil
    end
    if self.remove_favorite_subscription ~= nil then
        self.remove_favorite_subscription()
        self.remove_favorite_subscription = nil
    end
end

return LocationPanel
