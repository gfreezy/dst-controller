-- Virtual Cursor Core Module
-- Provides virtual cursor functionality with gamepad controls

local G = require("dst-controller/global")
local ConfigManager = require("dst-controller/utils/config_manager")

local VirtualCursor = {}

-- Constants
local FRAMES = G.FRAMES or (1/60) -- ~0.0167 seconds per frame @ 60fps
local START_DRAG_TIME = 8 * FRAMES  -- ~0.133 seconds (DST standard)
local BASE_CURSOR_SPEED = 400  -- Base pixels per second

-- State
local STATE = {
    cursor_mode_active = false,
    cursor_position = nil,  -- Vector3 world position
    cursor_screen_pos = {x = 0, y = 0},  -- Screen coordinates
    button_states = {
        primary = false,  -- RT (left-click)
        secondary = false,  -- RB (right-click)
    },
    cursor_widget = nil,  -- Will be set by cursor_widget.lua
    hover_entity = nil,  -- Currently hovered entity
    last_hover_update_pos = {x = 0, y = 0},  -- Last position where hover was updated
    last_toggle_time = 0,  -- Last time cursor mode was toggled
}

-- Helper function to get config with validation
local function GetConfig()
    local settings = ConfigManager.GetRuntimeSettings()
    local config = settings.virtual_cursor_settings or {}

    -- Validate and apply defaults
    return {
        enabled = config.enabled ~= false,  -- Default true
        toggle_combo = config.toggle_combo or {"LB", "RB", "RT"},
        left_click_key = config.left_click_key or "RT",
        right_click_key = config.right_click_key or "RB",
        cursor_speed = math.max(0.1, math.min(3.0, config.cursor_speed or 1.0)),  -- Clamp 0.1-3.0
        dead_zone = math.max(0.0, math.min(0.5, config.dead_zone or 0.1)),  -- Clamp 0.0-0.5
        show_cursor = config.show_cursor ~= false,  -- Default true
    }
end

-- Helper function to get control code from string
local function GetControlCode(key_name)
    if not key_name then
        return nil
    end

    local control_map = {
        LB = G.CONTROL_ROTATE_LEFT,
        RB = G.CONTROL_ROTATE_RIGHT,
        LT = G.CONTROL_ZOOM_IN,
        RT = G.CONTROL_ZOOM_OUT,
        A = G.CONTROL_ACCEPT,
        B = G.CONTROL_CANCEL,
        X = G.CONTROL_MENU_MISC_1,
        Y = G.CONTROL_MENU_MISC_2,
        LS = G.CONTROL_MENU_L3,
        RS = G.CONTROL_MENU_R3,
    }

    local control = control_map[key_name]
    if not control then
        print("[VirtualCursor] Warning: Invalid key name: " .. tostring(key_name))
        return nil
    end

    return control
end

-- Initialize cursor position
local function InitializeCursorPosition()
    if G.ThePlayer then
        -- Start cursor at screen center
        local w, h = G.TheSim:GetScreenSize()
        STATE.cursor_screen_pos.x = w / 2
        STATE.cursor_screen_pos.y = h / 2

        -- Project to world position
        local x, y, z = G.TheSim:ProjectScreenPos(w / 2, h / 2)

        if x and y and z then
            STATE.cursor_position = G.Vector3(x, y, z)
        else
            -- Fallback to player position if projection fails
            STATE.cursor_position = G.ThePlayer:GetPosition()
            -- Update screen position from world position
            VirtualCursor.UpdateScreenPosition()
        end

        -- Update widget
        if STATE.cursor_widget then
            STATE.cursor_widget:SetPosition(STATE.cursor_screen_pos.x, STATE.cursor_screen_pos.y)
        end
    end
end

-- Toggle cursor mode on/off
function VirtualCursor.ToggleCursorMode()
    local config = GetConfig()

    if not config.enabled then
        return
    end

    -- Prevent toggle spam (minimum 0.3 seconds between toggles)
    local GetTime = G.GetTime or _G.GetTime
    local current_time = GetTime and GetTime() or 0
    if current_time - STATE.last_toggle_time < 0.3 then
        return
    end
    STATE.last_toggle_time = current_time

    STATE.cursor_mode_active = not STATE.cursor_mode_active

    if STATE.cursor_mode_active then
        -- Entering cursor mode
        InitializeCursorPosition()

        if STATE.cursor_widget and config.show_cursor then
            STATE.cursor_widget:Show()
        end

        print("[VirtualCursor] Cursor mode activated")
    else
        -- Exiting cursor mode
        if STATE.cursor_widget then
            STATE.cursor_widget:Hide()
        end

        -- Reset button states
        STATE.button_states.primary = false
        STATE.button_states.secondary = false

        print("[VirtualCursor] Cursor mode deactivated")
    end
end

-- Check if cursor mode is active
function VirtualCursor.IsCursorModeActive()
    return STATE.cursor_mode_active
end

-- Update cursor position based on right stick input
function VirtualCursor.UpdateCursorPosition(dt, stick_x, stick_y)
    if not STATE.cursor_mode_active then
        return
    end

    local config = GetConfig()
    local dead_zone = config.dead_zone or 0.1

    -- Early return if both axes are in dead zone
    if math.abs(stick_x) < dead_zone and math.abs(stick_y) < dead_zone then
        return
    end

    -- Apply dead zone to each axis
    if math.abs(stick_x) < dead_zone then stick_x = 0 end
    if math.abs(stick_y) < dead_zone then stick_y = 0 end

    -- Calculate speed (pixels per second)
    local speed = BASE_CURSOR_SPEED * (config.cursor_speed or 1.0)

    -- Update screen position directly (easier to clamp to screen bounds)
    STATE.cursor_screen_pos.x = STATE.cursor_screen_pos.x + stick_x * speed * dt
    STATE.cursor_screen_pos.y = STATE.cursor_screen_pos.y - stick_y * speed * dt

    -- Clamp to screen bounds
    local screen_w, screen_h = G.TheSim:GetScreenSize()
    STATE.cursor_screen_pos.x = math.max(0, math.min(screen_w, STATE.cursor_screen_pos.x))
    STATE.cursor_screen_pos.y = math.max(0, math.min(screen_h, STATE.cursor_screen_pos.y))

    -- Update world position from screen position
    VirtualCursor.UpdateWorldPosition()
end

-- Update world position from screen position
function VirtualCursor.UpdateWorldPosition()
    if not STATE.cursor_screen_pos then
        return
    end

    -- Project screen position to world coordinates
    local x, y, z = G.TheSim:ProjectScreenPos(
        STATE.cursor_screen_pos.x,
        STATE.cursor_screen_pos.y
    )

    if x and y and z then
        STATE.cursor_position = G.Vector3(x, y, z)
    end

    -- Update widget position
    if STATE.cursor_widget then
        STATE.cursor_widget:SetPosition(STATE.cursor_screen_pos.x, STATE.cursor_screen_pos.y)
    end
end

-- Update screen position from world position (used during initialization)
function VirtualCursor.UpdateScreenPosition()
    if not STATE.cursor_position then
        return
    end

    local screen_x, screen_y = G.TheSim:WorldPosToScreenPos(
        STATE.cursor_position.x,
        STATE.cursor_position.y or 0,
        STATE.cursor_position.z
    )

    if screen_x and screen_y then
        STATE.cursor_screen_pos.x = screen_x
        STATE.cursor_screen_pos.y = screen_y

        -- Update widget position
        if STATE.cursor_widget then
            STATE.cursor_widget:SetPosition(screen_x, screen_y)
        end
    end
end

-- Get all entities at cursor position (using screen coordinates for accuracy)
function VirtualCursor.GetEntitiesAtCursor()
    if not STATE.cursor_position or not STATE.cursor_screen_pos then
        return {}
    end

    -- Use DST's screen-based entity detection (more accurate for UI/world objects)
    local entities = G.TheSim:GetEntitiesAtScreenPoint(STATE.cursor_screen_pos.x, STATE.cursor_screen_pos.y)

    return entities or {}
end

-- Get primary entity at cursor position (handles forwarding and mouse-through)
function VirtualCursor.GetEntityAtCursor()
    local entities = VirtualCursor.GetEntitiesAtCursor()

    if #entities > 0 then
        local inst = entities[1]

        -- Handle client_forward_target (some entities forward to another entity)
        if inst and inst.client_forward_target then
            inst = inst.client_forward_target
        end

        -- Handle mouse-through entities (walls, etc.)
        if inst and inst.CanMouseThrough then
            local mousethrough, keepnone = inst:CanMouseThrough()
            if mousethrough then
                -- Find next valid entity
                for i = 2, #entities do
                    local nextinst = entities[i]
                    if nextinst and nextinst.client_forward_target then
                        nextinst = nextinst.client_forward_target
                    end
                    if nextinst and nextinst:IsValid() and not (keepnone and nextinst == G.ThePlayer) then
                        inst = nextinst
                        break
                    end
                end
            end
        end

        -- Validate entity
        if inst and inst:IsValid() and inst.entity:IsVisible() then
            return inst
        end
    end

    return nil
end

-- Simulate mouse button press/release
-- This directly calls DST's controller methods, which will use our hooked Input methods
-- DST will handle all drag detection internally via playercontroller.draggingonground
function VirtualCursor.SimulateMouseButton(button, down)
    if not STATE.cursor_mode_active or not G.ThePlayer then
        return
    end

    local controller = G.ThePlayer.components.playercontroller
    if not controller then
        return
    end

    -- Update button state (used by IsControlPressed hook)
    local button_type = (button == G.CONTROL_PRIMARY) and "primary" or "secondary"
    STATE.button_states[button_type] = down

    -- Call DST's controller methods directly
    -- DST will handle drag detection, action computation, and execution
    if button == G.CONTROL_PRIMARY then
        controller:OnLeftClick(down)
    elseif button == G.CONTROL_SECONDARY then
        controller:OnRightClick(down)
    end
end

-- Update hover entity detection (called in OnUpdate)
-- Rate limited to avoid expensive GetEntitiesAtScreenPoint calls every frame
function VirtualCursor.UpdateHoverEntity()
    if not STATE.cursor_mode_active then
        STATE.hover_entity = nil
        return
    end

    -- Rate limit: only update hover if cursor moved significantly (>5 pixels)
    local dx = STATE.cursor_screen_pos.x - STATE.last_hover_update_pos.x
    local dy = STATE.cursor_screen_pos.y - STATE.last_hover_update_pos.y
    local dist_sq = dx * dx + dy * dy

    if dist_sq < 25 then  -- < 5 pixels movement
        return
    end

    -- Update last position
    STATE.last_hover_update_pos.x = STATE.cursor_screen_pos.x
    STATE.last_hover_update_pos.y = STATE.cursor_screen_pos.y

    -- Get entity under cursor (expensive operation)
    local new_hover = VirtualCursor.GetEntityAtCursor()

    -- Check if hover entity changed
    if new_hover ~= STATE.hover_entity then
        -- Fire mouseout event on old entity
        if STATE.hover_entity and STATE.hover_entity:IsValid() then
            STATE.hover_entity:PushEvent("mouseout")
        end

        -- Fire mouseover event on new entity
        if new_hover and new_hover:IsValid() then
            new_hover:PushEvent("mouseover")
        end

        STATE.hover_entity = new_hover
    end
end

-- Check if currently dragging (reads DST's internal state)
-- DST handles drag detection in playercontroller:OnUpdate
function VirtualCursor.IsDragging()
    if not STATE.cursor_mode_active or not G.ThePlayer then
        return false
    end

    local controller = G.ThePlayer.components.playercontroller
    if not controller then
        return false
    end

    -- Read DST's drag state directly
    return controller.draggingonground or false
end

-- Check if combination keys are pressed
function VirtualCursor.IsToggleComboPressed()
    local config = GetConfig()
    local combo = config.toggle_combo or {"LB", "RB", "RT"}

    for _, key_name in ipairs(combo) do
        local control = GetControlCode(key_name)
        if not control or not G.TheInput:IsControlPressed(control) then
            return false
        end
    end

    return true
end

-- Get mapped control for left/right click
function VirtualCursor.GetClickControl(button_type)
    local config = GetConfig()
    local key_name = (button_type == "left") and config.left_click_key or config.right_click_key
    return GetControlCode(key_name)
end

-- Set cursor widget reference
function VirtualCursor.SetCursorWidget(widget)
    STATE.cursor_widget = widget
end

-- Get current cursor position
function VirtualCursor.GetCursorPosition()
    return STATE.cursor_position
end

-- Get current cursor screen position
function VirtualCursor.GetCursorScreenPosition()
    return STATE.cursor_screen_pos
end

-- Get button states
function VirtualCursor.GetButtonStates()
    return STATE.button_states
end

-- Get state (for debugging)
function VirtualCursor.GetState()
    return STATE
end

return VirtualCursor
