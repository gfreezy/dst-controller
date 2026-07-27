-- Enhanced Controller - player and favorite location content for its modal screen

local G = require("dst-controller/global")
local PlayerService = require("dst-controller/locations/player-service")
local FavoritesStore = require("dst-controller/locations/favorites-store")
local L = require("dst-controller/localization").L

local Widget = require("widgets/widget")
local Text = require("widgets/text")
local PlayerBadge = require("widgets/playerbadge")
local TEMPLATES = require("widgets/redux/templates")
local HeaderTabs = require("widgets/redux/headertabs")
local InputDialogScreen = require("screens/redux/inputdialog")

local PANEL_WIDTH = 700
local PANEL_HEIGHT = 560
local ROW_WIDTH = 620
local ROW_HEIGHT = 52
local VISIBLE_ROWS = 7

local LocationPanel = G.Class(Widget, function(self, on_close, on_navigate)
    Widget._ctor(self, "EnhancedLocationPanel")
    self.active_tab = "players"
    self.rows_data = {}
    self.on_close = on_close
    self.on_navigate = on_navigate

    self.frame = self:AddChild(TEMPLATES.RectangleWindow(PANEL_WIDTH,
        PANEL_HEIGHT, nil, {
            {
                text = L("BUTTON_CLOSE"),
                cb = function()
                    if self.on_close ~= nil then
                        self.on_close()
                    end
                end,
            },
        }))
    self.frame:SetScale(1, 1)
    self.close_button = self.frame.actions.items[1]
    -- HeaderTabs supplies the top edge, matching native Redux windows.
    if self.frame.top ~= nil then
        self.frame.top:Hide()
    end
    self.frame:MoveToBack()

    self.header_tabs = self:AddChild(HeaderTabs({
        {
            text = L("LOCATION_TAB_PLAYERS"),
            cb = function() self:SetTab("players") end,
        },
        {
            text = L("LOCATION_TAB_FAVORITES"),
            cb = function() self:SetTab("favorites") end,
        },
    }, true))
    self.header_tabs:SetPosition(0, PANEL_HEIGHT / 2 + 25)

    self.action_button = self:AddChild(TEMPLATES.StandardButton(function()
        self:RunPrimaryAction()
    end, "", { 260, 42 }))
    self.action_button:SetPosition(0, 218)

    local function MakeRow(_, index)
        local row = Widget("enhanced_location_row_" .. tostring(index))
        row.main = row:AddChild(TEMPLATES.StandardButton(function()
            self:ActivateRow(row.data)
        end, "", { 390, 46 }))
        row.secondary = row:AddChild(TEMPLATES.StandardButton(function()
            self:SecondaryRowAction(row.data)
        end, "", { 105, 42 }))
        row.tertiary = row:AddChild(TEMPLATES.StandardButton(function()
            self:TertiaryRowAction(row.data)
        end, "", { 105, 42 }))
        row.player_badge = row:AddChild(PlayerBadge(
            "", G.DEFAULT_PLAYER_COLOUR, false, 0))
        row.player_badge:SetScale(0.45)
        row.player_badge:SetPosition(-276, 0)
        row.player_badge:Hide()
        row.main:SetPosition(-55, 0)
        row.main:SetTextSize(22)
        row.secondary:SetPosition(230, 0)
        row.secondary:SetTextSize(19)
        row.tertiary:SetPosition(230, 0)
        row.tertiary:SetTextSize(19)

        row.main:SetFocusChangeDir(G.MOVE_RIGHT, row.secondary)
        row.secondary:SetFocusChangeDir(G.MOVE_LEFT, row.main)
        row.secondary:SetFocusChangeDir(G.MOVE_RIGHT, row.tertiary)
        row.tertiary:SetFocusChangeDir(G.MOVE_LEFT, row.secondary)
        row.focus_forward = function()
            return row.main:IsEnabled() and row.main or row.secondary
        end
        row:SetOnGainFocus(function()
            if self.scroll_list ~= nil then
                self.scroll_list:OnWidgetFocus(row)
            end
        end)
        return row
    end

    local function ApplyRow(_, row, data)
        self:ApplyRow(row, data)
    end

    self.scroll_list = self:AddChild(TEMPLATES.ScrollingGrid({}, {
        scroll_context = { panel = self },
        widget_width = ROW_WIDTH,
        widget_height = ROW_HEIGHT,
        num_visible_rows = VISIBLE_ROWS,
        num_columns = 1,
        item_ctor_fn = MakeRow,
        apply_fn = ApplyRow,
        scrollbar_offset = 18,
        scrollbar_height_offset = -35,
        peek_percent = 0,
        scroll_per_click = 1,
    }))
    self.scroll_list:SetPosition(-2, -25)

    -- Move directly from the final data row to the window action. Letting
    -- TrueScrollList perform its normal boundary traversal can briefly focus
    -- one of its hidden recycled rows, which looks like focus was lost.
    local old_scroll_onfocusmove = self.scroll_list.OnFocusMove
    self.scroll_list.OnFocusMove = function(scroll_list, dir, down)
        if down and dir == G.MOVE_DOWN and #scroll_list.items > 0 then
            local focused_item_index = scroll_list.itemfocus or
                (scroll_list.focused_widget_index +
                    scroll_list.displayed_start_index)
            if focused_item_index >= #scroll_list.items then
                self.close_button:SetFocus()
                return true
            end
        end
        return old_scroll_onfocusmove(scroll_list, dir, down)
    end

    self.empty_text = self:AddChild(Text(
        G.BODYTEXTFONT, 22, "", G.UICOLOURS.GOLD_UNIMPORTANT))
    self.empty_text:SetPosition(0, -25)

    self.header_tabs:SetFocusChangeDir(G.MOVE_DOWN, function()
        return self:GetFirstContentFocus()
    end)
    self.action_button:SetFocusChangeDir(G.MOVE_UP, self.header_tabs)
    self.action_button:SetFocusChangeDir(G.MOVE_DOWN, function()
        return #self.rows_data > 0 and
            self:GetListFocusTarget(1) or self.close_button
    end)
    self.scroll_list:SetFocusChangeDir(G.MOVE_UP, function()
        return self.action_button:IsEnabled() and
            self.action_button or self.header_tabs
    end)
    self.scroll_list:SetFocusChangeDir(G.MOVE_DOWN, self.close_button)
    self.close_button:SetFocusChangeDir(G.MOVE_UP, function()
        if #self.rows_data > 0 then
            return self:GetListFocusTarget(#self.rows_data)
        end
        return self.action_button:IsEnabled() and
            self.action_button or self.header_tabs
    end)
    self.focus_forward = self.header_tabs

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
    if self.header_tabs ~= nil then
        self.header_tabs:SelectButton(tab == "players" and 1 or 2)
    end
    self:Refresh()
    if self.scroll_list ~= nil then
        self.scroll_list:ResetScroll()
    end
end

function LocationPanel:CycleTab(direction)
    local index = self.active_tab == "players" and 1 or 2
    index = ((index - 1 + direction) % 2) + 1
    self:SetTab(index == 1 and "players" or "favorites")
end

function LocationPanel:GetFirstContentFocus()
    if self.action_button:IsEnabled() then
        return self.action_button
    end
    if #self.rows_data > 0 then
        return self:GetListFocusTarget(1)
    end
    return self.close_button
end

function LocationPanel:GetListFocusTarget(data_index)
    local item_count = #self.rows_data
    if item_count == 0 then
        return self.close_button
    end

    data_index = math.max(1, math.min(data_index, item_count))
    self.scroll_list:ScrollToDataIndex(data_index)
    local widget_index = data_index - self.scroll_list.displayed_start_index
    return self.scroll_list.widgets_to_update[widget_index] or self.scroll_list
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
    local list_had_focus = self.scroll_list.focus == true

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

    self.scroll_list:SetItemsData(self.rows_data)

    if #self.rows_data == 0 then
        self.empty_text:SetString(self.active_tab == "players" and
            L("LOCATION_NO_PLAYERS") or L("LOCATION_NO_FAVORITES"))
        self.empty_text:Show()
        if list_had_focus then
            self:GetFirstContentFocus():SetFocus()
        end
    else
        self.empty_text:Hide()
    end
end

function LocationPanel:ApplyRow(row, data)
    row.data = data
    if data == nil then
        row:Hide()
        return
    end
    row:Show()
    row.main:Show()
    row.secondary:Show()

    if self.active_tab == "players" then
        local position = data.position
        row.player_badge:Set(
            data.prefab or "",
            data.colour or G.DEFAULT_PLAYER_COLOUR,
            false,
            data.userflags or 0,
            data.base_skin)
        row.player_badge:Show()
        row.main:ForceImageSize(400, 46)
        row.main:SetPosition(-55, 0)
        row.secondary:ForceImageSize(120, 42)
        row.secondary:SetPosition(230, 0)
        local label = data.name
        row.main:SetText(label)
        row.main.text:SetTruncatedString(label, 360, 32, true)
        row.main:SetTooltip(label)
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
        row.player_badge:Hide()
        row.main:ForceImageSize(400, 46)
        row.main:SetPosition(-100, 0)
        row.secondary:ForceImageSize(90, 42)
        row.secondary:SetPosition(160, 0)
        row.tertiary:ForceImageSize(90, 42)
        row.tertiary:SetPosition(260, 0)
        local label = data.name
        row.main:SetText(label)
        row.main.text:SetTruncatedString(label, 360, 32, true)
        row.main:SetTooltip(label)
        if data.current_shard then
            row.main:Enable()
        else
            row.main:Disable()
        end
        row.secondary:SetText(L("BUTTON_EDIT"))
        row.tertiary:SetText(L("BUTTON_DELETE"))
        row.secondary:Enable()
        row.secondary:Show()
        row.tertiary:Enable()
        row.tertiary:Show()
    end
end

function LocationPanel:ActivateRow(data)
    local position = data ~= nil and
        (self.active_tab == "players" and data.position or data) or nil
    if position ~= nil and position.current_shard and
        self.on_navigate ~= nil then
        self.on_navigate(position)
    end
end

function LocationPanel:SecondaryRowAction(data)
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

function LocationPanel:TertiaryRowAction(data)
    if self.active_tab == "favorites" and data ~= nil then
        FavoritesStore.Remove(data.id)
    end
end

function LocationPanel:GetDefaultFocus()
    return self.header_tabs
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
