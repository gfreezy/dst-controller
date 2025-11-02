-- Virtual Cursor Core Module
-- Provides virtual cursor functionality with gamepad controls

local G = require("dst-controller/global")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")

local VirtualCursor = {}

-- Constants (inspired by dst-mod khy_fs.lua)
local BASE_SPEED_DIVISOR = 33  -- Used to calculate base speed from screen resolution
local SPEED_RATE_DEFAULT = 9  -- Default speed multiplier (9/10 = 0.9)
local DEAD_ZONE_DEFAULT = 0.2  -- Default dead zone threshold (20%)

-- Scene-specific speed multipliers
local SPEED_MULTIPLIERS = {
    NORMAL = 1.0,           -- Normal movement
    UI_HOVER = 0.4,         -- Hovering over UI elements (ui_slow_rate)
    ENTITY_HOVER = 0.65,    -- Hovering over entities (slow_rate)
    BUILDING = 0.25,        -- Building/placement mode (placer_slow_rate)
    PLANTING = 0.5,         -- Planting mode (plant_slow_rate)
    LIMITED = 0.7,          -- Limited speed mode
}

-- State
local STATE = {
    cursor_mode_active = false,
    ---@type Vector3|nil
    cursor_position = nil,
    ---@type {x: number, y: number}
    cursor_screen_pos = {x = 0, y = 0},  -- Screen coordinates
    button_states = {
        primary = false,  -- LT (left-click)
        secondary = false,  -- RT (right-click)
    },
    cursor_widget = nil,  -- Will be set by cursor_widget.lua
    last_toggle_time = 0,  -- Last time cursor mode was toggled

    -- Speed control state (for smooth transitions)
    base_cursor_speed = 0,  -- Calculated from screen resolution (pixels per frame at 60fps)
    current_speed_multiplier = SPEED_MULTIPLIERS.NORMAL,
    target_speed_multiplier = SPEED_MULTIPLIERS.NORMAL,
    speed_transition_rate = 2.0,  -- Speed recovery rate (per second)
    is_hovering_ui = false,
    is_hovering_entity = false,
}

-- Helper function to get config with validation
local function GetConfig()
    local settings = ConfigManager.GetRuntimeSettings()
    local config = settings.virtual_cursor_settings or {}

    -- Validate and apply defaults
    return {
        enabled = config.enabled ~= false,  -- Default true
        toggle_combo = config.toggle_combo or {"LB", "RB", "RT"},
        left_click_key = "LT",
        right_click_key = "RT",
        cursor_speed = math.max(0.1, math.min(3.0, config.cursor_speed or 1.0)),  -- Clamp 0.1-3.0
        dead_zone = math.max(0.0, math.min(0.5, config.dead_zone or DEAD_ZONE_DEFAULT)),  -- Clamp 0.0-0.5, default 0.2
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


-- Calculate base cursor speed from screen resolution
-- Formula: |width - height| / BASE_SPEED_DIVISOR
-- This makes speed adaptive to screen size (inspired by dst-mod)
local function CalculateBaseCursorSpeed()
    local w, h = G.TheSim:GetScreenSize()
    -- Use absolute difference between width and height
    -- For 1920x1080: |1920-1080|/33 ≈ 25.45 pixels/frame
    -- For 2560x1440: |2560-1440|/33 ≈ 33.94 pixels/frame
    STATE.base_cursor_speed = math.abs(w - h) / BASE_SPEED_DIVISOR
    print(string.format("[VirtualCursor] Base speed calculated: %.2f pixels/frame (screen: %dx%d)",
        STATE.base_cursor_speed, w, h))
end

-- Initialize cursor position
local function InitializeCursorPosition()
    if G.ThePlayer then
        -- Calculate base speed first
        CalculateBaseCursorSpeed()

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
        -- Note: We also hook Input:OnUpdate to force mouse_enabled=true every frame
        if G.TheInput and G.TheInput.EnableMouse then
            G.TheInput:EnableMouse(true)
        end

        if STATE.cursor_widget and config.show_cursor then
            STATE.cursor_widget:Show()
        end

        if G.ThePlayer and G.ThePlayer.HUD and G.ThePlayer.HUD.controls then
            local inventorybar = G.ThePlayer.HUD.controls.inv
            if inventorybar then
                -- Clear active_slot to reset selection state
                if inventorybar.active_slot then
                    inventorybar.active_slot:DeHighlight()
                end
            end
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

function VirtualCursor.SetCursorPosition(x, y)
    if not STATE.cursor_mode_active then
        return
    end
    STATE.cursor_screen_pos.x = x
    STATE.cursor_screen_pos.y = y
    VirtualCursor.UpdateWorldPosition()
end

-- Get adjusted cursor speed based on scene context
-- Implements smooth speed transitions and scene-aware speed multipliers (inspired by dst-mod)
local function GetAdjustedCursorSpeed(dt, config)
    -- Base speed calculation: (SPEED_RATE_DEFAULT / 10) * base_cursor_speed * user_speed_multiplier
    -- This gives us pixels per frame (assuming 60fps)
    local speed_rate = (SPEED_RATE_DEFAULT / 10.0) * (config.cursor_speed or 1.0)
    local base_speed = speed_rate * STATE.base_cursor_speed

    -- Check if player is in building/planting mode
    if G.ThePlayer and G.ThePlayer.components and G.ThePlayer.components.playercontroller then
        local controller = G.ThePlayer.components.playercontroller

        -- Building mode (placer active)
        if controller.placer ~= nil then
            STATE.target_speed_multiplier = SPEED_MULTIPLIERS.BUILDING
            return base_speed * SPEED_MULTIPLIERS.BUILDING
        end

        -- Deploy placement mode (also building)
        if controller.deployplacer ~= nil then
            STATE.target_speed_multiplier = SPEED_MULTIPLIERS.BUILDING
            return base_speed * SPEED_MULTIPLIERS.BUILDING
        end
    end

    -- Check hover state for UI elements
    if STATE.is_hovering_ui then
        STATE.target_speed_multiplier = SPEED_MULTIPLIERS.UI_HOVER
    -- Check hover state for entities
    elseif STATE.is_hovering_entity then
        STATE.target_speed_multiplier = SPEED_MULTIPLIERS.ENTITY_HOVER
    else
        STATE.target_speed_multiplier = SPEED_MULTIPLIERS.NORMAL
    end

    -- Smooth speed transition (gradual recovery to target speed)
    if STATE.current_speed_multiplier < STATE.target_speed_multiplier then
        -- Accelerate towards target speed
        STATE.current_speed_multiplier = math.min(
            STATE.target_speed_multiplier,
            STATE.current_speed_multiplier + dt * STATE.speed_transition_rate
        )
    elseif STATE.current_speed_multiplier > STATE.target_speed_multiplier then
        -- Instantly apply slower speed (no delay when slowing down)
        STATE.current_speed_multiplier = STATE.target_speed_multiplier
    end

    return base_speed * STATE.current_speed_multiplier
end

-- Update cursor position based on right stick input (optimized algorithm from dst-mod)
function VirtualCursor.UpdateCursorPositionDelta(dt, stick_x, stick_y)
    if not STATE.cursor_mode_active then
        return
    end

    -- ===== Step 1: Get stick input values =====
    -- stick_x, stick_y are already in range [-1, 1] from analog controls
    local abs_x = math.abs(stick_x)
    local abs_y = math.abs(stick_y)

    local config = GetConfig()
    local dead_zone = config.dead_zone or DEAD_ZONE_DEFAULT

    -- ===== Step 2: Apply dead zone filtering =====
    -- Early return if both axes are in dead zone
    if abs_x < dead_zone and abs_y < dead_zone then
        return
    end

    -- Apply dead zone to each axis independently
    if abs_x < dead_zone then stick_x = 0 end
    if abs_y < dead_zone then stick_y = 0 end

    -- Recalculate absolute values after dead zone
    abs_x = math.abs(stick_x)
    abs_y = math.abs(stick_y)

    -- ===== Step 3: Calculate stick intensity (0-1) =====
    -- Use sum of absolute values, clamped to 1.0 (dst-mod style)
    local stick_intensity = math.min(1.0, abs_x + abs_y)

    -- ===== Step 4: Get adjusted speed based on scene context =====
    local adjusted_speed = GetAdjustedCursorSpeed(dt, config)

    -- Convert to pixels per second (multiply by 60 to simulate 60fps)
    local speed_per_second = adjusted_speed * 60

    -- ===== Step 5: Calculate displacement for this frame =====
    -- delta = direction × speed × intensity × dt
    local delta_x = stick_x * speed_per_second * stick_intensity * dt
    local delta_y = stick_y * speed_per_second * stick_intensity * dt

    -- ===== Step 6: Store old position =====
    local old_x = STATE.cursor_screen_pos.x
    local old_y = STATE.cursor_screen_pos.y

    -- ===== Step 7: Calculate new position with floor() for pixel precision =====
    local new_x = math.floor(abs_x > 0 and old_x + delta_x or old_x)
    local new_y = math.floor(abs_y > 0 and old_y + delta_y or old_y)

    -- ===== Step 8: Clamp to screen bounds =====
    local screen_w, screen_h = G.TheSim:GetScreenSize()
    new_x = math.max(0, math.min(screen_w, new_x))
    new_y = math.max(0, math.min(screen_h, new_y))

    -- ===== Step 9: Update position if changed =====
    if new_x ~= old_x or new_y ~= old_y then
        STATE.cursor_screen_pos.x = new_x
        STATE.cursor_screen_pos.y = new_y

        -- ===== Step 10: Trigger input events for hover detection =====
        if G.TheInput and G.TheInput.OnMouseMove then
            G.TheInput:OnMouseMove(new_x, new_y)
        end

        if G.TheInput and G.TheInput.UpdatePosition then
            G.TheInput:UpdatePosition(new_x, new_y)
        end

        -- ===== Step 11: Update world position and hover state =====
        VirtualCursor.UpdateWorldPosition()
        VirtualCursor.UpdateHoverState()
    end
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

-- Update hover state for scene-aware speed adjustment
function VirtualCursor.UpdateHoverState()
    if not G.TheInput then
        return
    end

    -- Reset hover states
    STATE.is_hovering_ui = false
    STATE.is_hovering_entity = false

    -- Check if hovering over a widget (UI element)
    -- TheFrontEnd:GetFocusWidget() returns the currently focused widget
    if G.TheFrontEnd then
        local focus_widget = G.TheFrontEnd:GetFocusWidget()
        if focus_widget then
            STATE.is_hovering_ui = true
            return  -- UI takes priority over entities
        end
    end

    -- Check if hovering over an entity
    -- TheInput.hoverinst is automatically updated by DST's input system
    if G.TheInput.hoverinst and G.TheInput.hoverinst:IsValid() then
        -- Check if the entity is interactable (not just decoration)
        local entity = G.TheInput.hoverinst
        if not (entity:HasTag("NOCLICK") or entity:HasTag("FX") or entity:HasTag("DECOR") or entity:HasTag("INLIMBO")) then
            STATE.is_hovering_entity = true
        end
    end
end


-- Simulate mouse button press/release
-- This triggers the proper mouse event chain through FrontEnd for UI focus handling
-- Then calls DST's controller methods for game actions
---@param button "left" | "right"
---@param down boolean
function VirtualCursor.SimulateMouseButton(button, down)
    if not STATE.cursor_mode_active or not G.ThePlayer then
        return
    end

    local controller = G.ThePlayer.components.playercontroller
    if not controller then
        return
    end

    -- Update button state (used by IsControlPressed hook)
    local button_type = (button == "left") and "primary" or "secondary"
    STATE.button_states[button_type] = down

    local control = (button == "left") and G.CONTROL_PRIMARY or G.CONTROL_SECONDARY

    G.TheInput:OnControl(control, down)
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
            if control == G.CONTROL_MENU_L2 then
                VirtualCursor.SimulateMouseButton("left", down)
            end
            return true  -- Intercept
        end

        -- Handle right-click button
        local right_click_control_name = VirtualCursor.GetClickButtonName("right")
        if Helpers.IsControlNamedButton(control, right_click_control_name) then
            if control == G.CONTROL_MENU_R2 then
                VirtualCursor.SimulateMouseButton("right", down)
            end
            return true  -- Intercept
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
        VirtualCursor.UpdateCursorPositionDelta(dt, stick_x, stick_y)
        return true
    end

    return false
end


return VirtualCursor
