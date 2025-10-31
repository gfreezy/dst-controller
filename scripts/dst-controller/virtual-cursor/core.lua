-- Virtual Cursor Core Module
-- Provides virtual cursor functionality with gamepad controls

local G = require("dst-controller/global")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")

local VirtualCursor = {}

-- Constants
local BASE_CURSOR_SPEED = 400  -- Base pixels per second

-- State
local STATE = {
    cursor_mode_active = false,
    ---@type Vector3|nil
    cursor_position = nil,
    ---@type {x: number, y: number}
    cursor_screen_pos = {x = 0, y = 0},  -- Screen coordinates
    button_states = {
        primary = false,  -- RT (left-click)
        secondary = false,  -- RB (right-click)
    },
    cursor_widget = nil,  -- Will be set by cursor_widget.lua
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
        left_click_key = config.left_click_key or "LT",
        right_click_key = config.right_click_key or "RT",
        cursor_speed = math.max(0.1, math.min(3.0, config.cursor_speed or 1.0)),  -- Clamp 0.1-3.0
        dead_zone = math.max(0.0, math.min(0.5, config.dead_zone or 0.1)),  -- Clamp 0.0-0.5
        show_cursor = config.show_cursor ~= false,  -- Default true
    }
end

-- Hook management state
local HOOK_STATE = {
    thesim_mt = nil,
    original_index = nil,
    hooked = false,
}

-- Install TheSim:GetPosition hook
local function InstallTheSimHook()
    if HOOK_STATE.hooked then
        return  -- Already hooked
    end

    HOOK_STATE.thesim_mt = getmetatable(G.TheSim)
    HOOK_STATE.original_index = HOOK_STATE.thesim_mt.__index

    HOOK_STATE.thesim_mt.__index = function(t, k)
        if k == "GetPosition" then
            -- Get original GetPosition method
            local original_getpos
            if type(HOOK_STATE.original_index) == "function" then
                original_getpos = HOOK_STATE.original_index(t, "GetPosition")
            elseif type(HOOK_STATE.original_index) == "table" then
                original_getpos = HOOK_STATE.original_index["GetPosition"]
            end

            -- Return wrapped function
            return function(self)
                if STATE.cursor_mode_active then
                    local pos = STATE.cursor_screen_pos
                    return pos.x, pos.y
                end
                -- Call original
                if original_getpos then
                    return original_getpos(self)
                end
                return 0, 0
            end
        end

        -- Fallback for other methods
        if type(HOOK_STATE.original_index) == "function" then
            return HOOK_STATE.original_index(t, k)
        elseif type(HOOK_STATE.original_index) == "table" then
            return HOOK_STATE.original_index[k]
        end
        return nil
    end

    HOOK_STATE.hooked = true
end

-- Remove TheSim:GetPosition hook
local function UninstallTheSimHook()
    if not HOOK_STATE.hooked then
        return  -- Not hooked
    end

    -- Restore original metatable
    if HOOK_STATE.thesim_mt and HOOK_STATE.original_index then
        HOOK_STATE.thesim_mt.__index = HOOK_STATE.original_index
    end

    HOOK_STATE.hooked = false
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
-- @param force_state (optional) - true to force enable, false to force disable, nil to toggle
function VirtualCursor.ToggleCursorMode(force_state)
    local config = GetConfig()

    if not config.enabled then
        return
    end

    -- Prevent toggle spam (minimum 0.3 seconds between toggles)
    local GetTime = G.GetTime
    local current_time = GetTime and GetTime() or 0
    if current_time - STATE.last_toggle_time < 0.3 then
        return
    end
    STATE.last_toggle_time = current_time

    -- Determine new state based on parameter
    local new_state
    if force_state ~= nil then
        new_state = force_state  -- Use explicit state if provided
    else
        new_state = not STATE.cursor_mode_active  -- Toggle if not provided
    end

    -- No-op if already in desired state
    if STATE.cursor_mode_active == new_state then
        return
    end

    STATE.cursor_mode_active = new_state

    if STATE.cursor_mode_active then
        -- Entering cursor mode
        InstallTheSimHook()  -- Hook TheSim:GetPosition
        InitializeCursorPosition()

        -- Enable mouse mode in Input system (critical for hover detection!)
        if G.TheInput and G.TheInput.EnableMouse then
            G.TheInput:EnableMouse(true)
        end

        if STATE.cursor_widget and config.show_cursor then
            STATE.cursor_widget:Show()
        end

        print("[VirtualCursor] Cursor mode activated")
    else
        -- Exiting cursor mode
        UninstallTheSimHook()  -- Unhook TheSim:GetPosition

        -- Restore mouse enabled state based on controller attached
        if G.TheInput and G.TheInput.EnableMouse and G.TheInput.ControllerAttached then
            G.TheInput:EnableMouse(not G.TheInput:ControllerAttached())
        end

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
    STATE.cursor_screen_pos.y = STATE.cursor_screen_pos.y + stick_y * speed * dt  -- Changed to + for natural control

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

    if not (x and y) then
        STATE.cursor_screen_pos = {x = 400, y = 300}
    end

    -- Update widget position
    if STATE.cursor_widget then
        STATE.cursor_widget:SetPosition(STATE.cursor_screen_pos.x, STATE.cursor_screen_pos.y)
    end
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
    -- TheSim:GetPosition() is now globally hooked, so it will return virtual cursor position
    if button == G.CONTROL_PRIMARY then
        controller:OnLeftClick(down)
    elseif button == G.CONTROL_SECONDARY then
        controller:OnRightClick(down)
    end
end

-- Check if combination keys are pressed
function VirtualCursor.IsToggleComboPressed()
    local config = GetConfig()
    local combo = config.toggle_combo or {"LB", "RB", "RT"}

    -- Use Helpers.IsButtonPressed which handles all control mappings (including RT -> CONTROL_MENU_R2)
    for _, key_name in ipairs(combo) do
        if not Helpers.IsButtonPressed(key_name) then
            return false
        end
    end

    return true
end

-- Get mapped control for left/right click
function VirtualCursor.GetClickButtonName(button_type)
    local config = GetConfig()
    local key_name = (button_type == "left") and config.left_click_key or config.right_click_key
    return key_name
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

-- Get configuration
function VirtualCursor.GetConfig()
    return GetConfig()
end

-- ============================================================================
-- Control Input Handling
-- ============================================================================

-- Handle virtual cursor control inputs
-- This is called from playercontroller:OnControl hook
-- @param control - The control input
-- @param down - Whether the control is pressed (true) or released (false)
-- @return true if input was handled, false otherwise
function VirtualCursor.OnControl(control, down)
    -- Check for toggle combo (LB + RB + RT by default)
    -- Need to use raw input check because when cursor is active, ControllerAttached() returns false
    -- which might interfere with button detection
    local combo_config = GetConfig().toggle_combo or {"LB", "RB", "RT"}
    local combo_pressed = Helpers.IsComboButtonPressed(combo_config)

    if combo_pressed and down then
        -- Combo pressed, toggle cursor mode (no parameter = toggle behavior)
        VirtualCursor.ToggleCursorMode()
        return true  -- Intercept
    end

    -- If cursor mode is active, handle cursor controls
    if STATE.cursor_mode_active then
        -- Check if LB is pressed
        local lb_pressed = Helpers.IsButtonPressed("LB")

        -- Handle left-click button
        local left_click_control_name = VirtualCursor.GetClickButtonName("left")
        if Helpers.IsControlNamedButton(control, left_click_control_name) then
            if down then
                VirtualCursor.SimulateMouseButton(G.CONTROL_PRIMARY, true)
            else
                VirtualCursor.SimulateMouseButton(G.CONTROL_PRIMARY, false)
            end
            return true  -- Intercept
        end

        -- Handle right-click button
        local right_click_control_name = VirtualCursor.GetClickButtonName("right")
        if Helpers.IsControlNamedButton(control, right_click_control_name) then
            if down then
                VirtualCursor.SimulateMouseButton(G.CONTROL_SECONDARY, true)
            else
                VirtualCursor.SimulateMouseButton(G.CONTROL_SECONDARY, false)
            end
            return true  -- Intercept
        end

        -- If LB is pressed, don't intercept right stick (allow camera control)
        if lb_pressed then
            -- Let camera control work normally
            return false
        end
    end

    return false
end

function VirtualCursor.OnUpdate(self, dt)
    -- If cursor mode is active, update cursor position from right stick
    if not STATE.cursor_mode_active then
        return false
    end

    -- Check if LB is pressed
    local lb_pressed = Helpers.IsButtonPressed("LB")

    -- Only move cursor if LB is NOT pressed
    if not lb_pressed then
        -- Read right stick input
        local stick_x = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_RIGHT)
                        - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_LEFT)
        local stick_y = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_UP)
                        - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_DOWN)

        -- Update cursor position
        VirtualCursor.UpdateCursorPosition(dt, stick_x, stick_y)
        return true
    end

    return false
end


return VirtualCursor
