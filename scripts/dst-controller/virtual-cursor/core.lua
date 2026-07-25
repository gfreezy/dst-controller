-- Virtual Cursor Core Module
-- Provides virtual cursor functionality with gamepad controls

local G = require("dst-controller/global")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")
local ActionHelpers = require("dst-controller/actions/helpers")

local VirtualCursor = {}

-- Constants (inspired by dst-mod khy_fs.lua)
local BASE_SPEED_DIVISOR = 80  -- Longest screen edge / divisor = pixels per frame at 60fps
local SPEED_RATE_DEFAULT = 9  -- Default speed multiplier (9/10 = 0.9)
local DEAD_ZONE_DEFAULT = 0.2  -- Default dead zone threshold (20%)
local MAGNETISM_IDLE_DELAY = 0.08
local MAGNETISM_APPROACH_RATE = 12
local MAGNETISM_SNAP_DISTANCE = 6
local MAGNETISM_WORLD_RANGES = {1.25, 2.5, 4}

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
    auto_activated = false,  -- Whether cursor was auto-activated (e.g., for building mode)

    -- Speed control state (for smooth transitions)
    base_cursor_speed = 0,  -- Calculated from screen resolution (pixels per frame at 60fps)
    current_speed_multiplier = SPEED_MULTIPLIERS.NORMAL,
    target_speed_multiplier = SPEED_MULTIPLIERS.NORMAL,
    speed_transition_rate = 2.0,  -- Speed recovery rate (per second)
    is_hovering_ui = false,
    is_hovering_entity = false,

    -- Magnetism state
    tracking_target = nil,  -- Current magnetism target entity
    idle_state = false,  -- Whether the stick is inside the configured dead zone
    idle_wait_time = 0,  -- Time since stick became idle
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
        -- Magnetism settings
        cursor_magnetism = config.cursor_magnetism ~= false,  -- Default true
        magnetism_range = math.floor(math.max(1, math.min(3, config.magnetism_range or 2)) + 0.5),
        target_priority = config.target_priority == true,  -- Default false
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


-- Calculate base cursor speed from screen resolution.
-- Use the longest edge so square/ultrawide aspect ratios do not produce
-- unexpectedly slow (or even zero) movement.
local function CalculateBaseCursorSpeed()
    local w, h = G.TheSim:GetScreenSize()
    STATE.base_cursor_speed = math.max(w, h) / BASE_SPEED_DIVISOR
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
        STATE.current_speed_multiplier = SPEED_MULTIPLIERS.NORMAL
        STATE.target_speed_multiplier = SPEED_MULTIPLIERS.NORMAL
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0

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
-- @param auto_activate (optional) - true if this is an automatic activation (e.g., building mode)
function VirtualCursor.ToggleCursorMode(force_state, auto_activate)
    local config = GetConfig()

    if not config.enabled then
        return
    end

    -- Prevent toggle spam (minimum 0.3 seconds between toggles)
    local GetTime = G.GetTime
    local current_time = GetTime and GetTime() or 0
    if force_state == nil and current_time - STATE.last_toggle_time < 0.3 then
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
        STATE.auto_activated = auto_activate or false  -- Track if this is automatic activation

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

        print(string.format("[VirtualCursor] Cursor mode activated %s",
            STATE.auto_activated and "(auto)" or "(manual)"))
    else
        local controller = ActionHelpers.GetPlayerController(G.ThePlayer)
        if controller and controller.ClearActionHold then
            controller:ClearActionHold()
        end

        -- Clear active item (mouse-selected item) when exiting cursor mode
        local inventory = ActionHelpers.GetInventory(G.ThePlayer)
        if inventory and inventory.GetActiveItem and inventory:GetActiveItem() ~= nil then
            -- Return the active item to inventory instead of dropping it
            inventory:ReturnActiveItem()
            print("[VirtualCursor] Cleared active item on cursor mode exit")
        end

        -- Exiting cursor mode
        UninstallTheSimHook()  -- Unhook TheSim:GetPosition

        -- Clear cached controller state to force refresh
        if G.TheInput and G.TheInput.ClearCachedController then
            G.TheInput:ClearCachedController()
        end

        -- Restore mouse enabled state based on controller attached
        if G.TheInput and G.TheInput.EnableMouse and G.TheInput.ControllerAttached then
            G.TheInput:EnableMouse(not G.TheInput:ControllerAttached())
        end

        -- Stop mouse tracking mode and restore gamepad focus
        -- This fixes the issue where gamepad cursor is lost when opening crafting menu
        -- immediately after closing virtual cursor
        if G.TheFrontEnd and G.TheFrontEnd.StopTrackingMouse then
            -- StopTrackingMouse(true) will:
            -- - Set tracking_mouse = false
            -- - Call screen:SetDefaultFocus() if there's an active screen
            -- - If no screen, focus naturally returns to playercontroller
            G.TheFrontEnd:StopTrackingMouse(true)
        end

        if G.ThePlayer and G.ThePlayer.HUD and G.ThePlayer.HUD.controls then
            local inventorybar = G.ThePlayer.HUD.controls.inv
            if inventorybar then
                -- Highlight active_slot to reset selection state
                if inventorybar.active_slot then
                    inventorybar.active_slot:Highlight()
                end
            end
        end

        if STATE.cursor_widget then
            STATE.cursor_widget:Hide()
        end

        -- Reset button states
        STATE.button_states.primary = false
        STATE.button_states.secondary = false
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0

        -- Reset auto_activated flag
        STATE.auto_activated = false

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
    if G.ThePlayer then
        local controller = ActionHelpers.GetPlayerController(G.ThePlayer)
        if controller then

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

-- ============================================================================
-- Magnetism Functions
-- ============================================================================

-- Exclude tags for magnetism targets
local MAGNETISM_EXCLUDE_TAGS = {"FX", "DECOR", "INLIMBO", "NOCLICK", "notarget"}

-- Find nearest target for magnetism
-- Returns: distance_sq, screen_pos, entity
local function FindNearestTarget(center_pos, entities, exclude_entity)
    local nearest_dist_sq = math.huge
    local nearest_screen_pos = nil
    local nearest_entity = nil

    for _, entity in ipairs(entities) do
        -- Skip invalid entities
        if entity ~= exclude_entity and
           entity ~= G.ThePlayer and
           entity.entity:IsVisible() and
           entity:IsValid() then

            -- Check exclude tags
            local has_exclude_tag = false
            for _, tag in ipairs(MAGNETISM_EXCLUDE_TAGS) do
                if entity:HasTag(tag) then
                    has_exclude_tag = true
                    break
                end
            end

            if not has_exclude_tag then
                -- Get screen position
                local screen_pos = VirtualCursor.GetScreenPointFromEntity(entity)
                if screen_pos then
                    -- Calculate distance squared
                    local dist_sq = entity:GetDistanceSqToPoint(center_pos)

                    if dist_sq < nearest_dist_sq then
                        nearest_dist_sq = dist_sq
                        nearest_screen_pos = screen_pos
                        nearest_entity = entity
                    end
                end
            end
        end
    end

    return nearest_dist_sq, nearest_screen_pos, nearest_entity
end

-- Get screen position from entity (helper for magnetism)
function VirtualCursor.GetScreenPointFromEntity(entity)
    if not entity or not entity:IsValid() then
        return nil
    end

    local x, y, z = entity.Transform:GetWorldPosition()
    local screen_x, screen_y = G.TheSim:GetScreenPos(x, y, z)

    if screen_x and screen_y then
        local screen_w, screen_h = G.TheSim:GetScreenSize()
        if screen_x >= 0 and screen_x <= screen_w and screen_y >= 0 and screen_y <= screen_h then
            return {x = screen_x, y = screen_y}
        end
    end

    return nil
end

-- Update magnetism cursor position
-- Returns: new_screen_pos {x, y} or nil
function VirtualCursor.UpdateMagnetismCursor(dt, is_idle, current_screen_x, current_screen_y)
    local config = GetConfig()

    -- Magnetism targets world entities. It must not run on the full-map screen,
    -- where ProjectScreenPos refers to the world camera behind the map.
    local active_screen = G.TheFrontEnd and G.TheFrontEnd:GetActiveScreen() or nil
    local magnetism_blocked = active_screen ~= nil and active_screen.name == "MapScreen"

    if not config.cursor_magnetism or magnetism_blocked or STATE.is_hovering_ui or not G.ThePlayer then
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0
        return nil
    end

    -- Any deliberate stick input releases the target immediately. The previous
    -- < 0.5 threshold caused magnetism to fight slow, precise movement.
    if not is_idle then
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0
        return nil
    end

    if not STATE.idle_state then
        STATE.idle_state = true
        STATE.idle_wait_time = 0
    end
    STATE.idle_wait_time = STATE.idle_wait_time + dt
    if STATE.idle_wait_time < MAGNETISM_IDLE_DELAY then
        return nil
    end

    -- ===== Step 1: Determine search center and radius =====
    local search_center
    local search_radius

    if config.target_priority then
        -- Priority mode: search around player
        search_center = G.Vector3(G.ThePlayer.Transform:GetWorldPosition())
        search_radius = config.magnetism_range * 10
    else
        -- Normal mode: search around cursor
        local world_x, world_y, world_z = G.TheSim:ProjectScreenPos(current_screen_x, current_screen_y)
        if not world_x or not world_z then
            STATE.tracking_target = nil
            return nil
        end
        search_center = G.Vector3(world_x, world_y or 0, world_z)

        -- Short/medium/long must all be usable. The old short range was zero,
        -- which effectively disabled target acquisition.
        search_radius = MAGNETISM_WORLD_RANGES[config.magnetism_range]

        -- A slightly larger release radius prevents flicker at the boundary.
        if STATE.tracking_target then
            search_radius = search_radius * 1.35
        end
    end

    -- ===== Step 2: Find entities in range =====
    local entities = G.TheSim:FindEntities(
        search_center.x, search_center.y, search_center.z,
        search_radius,
        nil,  -- No must_have_tags
        MAGNETISM_EXCLUDE_TAGS  -- Exclude tags
    )

    -- ===== Step 3: Find nearest target =====
    local current_target = STATE.tracking_target
    local dist_sq, screen_pos, new_target

    -- Check if current target is still valid and in range
    if current_target and current_target:IsValid() then
        local still_in_range = false
        for _, entity in ipairs(entities) do
            if entity == current_target then
                still_in_range = true
                break
            end
        end

        if still_in_range then
            -- Keep current target
            dist_sq = current_target:GetDistanceSqToPoint(search_center)
            screen_pos = VirtualCursor.GetScreenPointFromEntity(current_target)
            new_target = current_target
        else
            -- Current target out of range, find new one
            dist_sq, screen_pos, new_target = FindNearestTarget(search_center, entities, current_target)
        end
    else
        -- No current target or invalid, find new one
        dist_sq, screen_pos, new_target = FindNearestTarget(search_center, entities, nil)
    end

    -- Update tracking target
    STATE.tracking_target = new_target

    -- ===== Step 4: Calculate magnetism position =====
    if new_target and screen_pos and dist_sq then
        local screen_dx = screen_pos.x - current_screen_x
        local screen_dy = screen_pos.y - current_screen_y
        local screen_dist_sq = screen_dx * screen_dx + screen_dy * screen_dy

        if screen_dist_sq <= MAGNETISM_SNAP_DISTANCE * MAGNETISM_SNAP_DISTANCE then
            return {x = screen_pos.x, y = screen_pos.y}
        else
            -- Frame-rate independent exponential approach.
            local alpha = 1 - math.exp(-MAGNETISM_APPROACH_RATE * dt)

            return {
                x = current_screen_x + screen_dx * alpha,
                y = current_screen_y + screen_dy * alpha
            }
        end
    end

    return nil
end

-- Update cursor position based on right stick input (optimized algorithm from dst-mod)
function VirtualCursor.UpdateCursorPositionDelta(dt, stick_x, stick_y)
    if not STATE.cursor_mode_active then
        return
    end

    local config = GetConfig()
    local dead_zone = config.dead_zone or DEAD_ZONE_DEFAULT

    -- Apply a radial dead zone and remap the remaining magnitude to [0, 1].
    -- This gives equal speed on cardinal and diagonal movement and preserves
    -- precise low-speed control without squaring the stick input.
    local raw_magnitude = math.sqrt(stick_x * stick_x + stick_y * stick_y)
    local is_idle = raw_magnitude <= dead_zone
    local direction_x, direction_y, stick_intensity = 0, 0, 0
    if not is_idle then
        local clamped_magnitude = math.min(1, raw_magnitude)
        direction_x = stick_x / raw_magnitude
        direction_y = stick_y / raw_magnitude
        stick_intensity = (clamped_magnitude - dead_zone) / math.max(0.001, 1 - dead_zone)
    end

    local old_x = STATE.cursor_screen_pos.x
    local old_y = STATE.cursor_screen_pos.y
    local new_x = old_x
    local new_y = old_y

    if not is_idle then
        local adjusted_speed = GetAdjustedCursorSpeed(dt, config)
        local speed_per_second = adjusted_speed * 60
        new_x = old_x + direction_x * speed_per_second * stick_intensity * dt
        new_y = old_y + direction_y * speed_per_second * stick_intensity * dt
    end

    -- Run this even when the stick is fully released. The previous early return
    -- made true idle magnetism impossible and only activated it during a light push.
    local magnetism_pos = VirtualCursor.UpdateMagnetismCursor(dt, is_idle, new_x, new_y)
    if magnetism_pos then
        new_x = magnetism_pos.x
        new_y = magnetism_pos.y
    end

    -- Keep sub-pixel state. floor() caused low-speed movement to stall toward
    -- positive axes while moving one pixel per frame toward negative axes.
    local screen_w, screen_h = G.TheSim:GetScreenSize()
    new_x = math.max(0, math.min(screen_w, new_x))
    new_y = math.max(0, math.min(screen_h, new_y))

    if new_x ~= old_x or new_y ~= old_y then
        STATE.cursor_screen_pos.x = new_x
        STATE.cursor_screen_pos.y = new_y

        if G.TheInput and G.TheInput.OnMouseMove then
            G.TheInput:OnMouseMove(new_x, new_y)
        end

        if G.TheInput and G.TheInput.UpdatePosition then
            G.TheInput:UpdatePosition(new_x, new_y)
        end

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

    local controller = ActionHelpers.GetPlayerController(G.ThePlayer)
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

-- Get cursor widget
function VirtualCursor.GetCursorWidget()
    return STATE.cursor_widget
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
-- This is called from thefrontend:OnControl hook
-- @param control - The control input
-- @param down - Whether the control is pressed (true) or released (false)
-- @return true if input was handled, false otherwise
function VirtualCursor.OnControl(control, down)
    -- If cursor mode is active, handle cursor controls
    if STATE.cursor_mode_active then
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

-- This is called from playhud:OnControl hook
function VirtualCursor.ToggleOnControl(control, down)
    local combo_config = GetConfig().toggle_combo or {"LB", "RB", "RT"}
    local combo_pressed = Helpers.IsComboButton(control, combo_config)

    if combo_pressed then
        if down then
            VirtualCursor.ToggleCursorMode()
        end
        return true
    end
    return false
end


-- This is called from thefrontend:OnUpdate hook
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

-- ============================================================================
-- Auto-Activation for Special Modes (Building, Map, etc.)
-- ============================================================================

-- Check if cursor was auto-activated
function VirtualCursor.IsAutoActivated()
    return STATE.auto_activated
end

-- Auto-enable virtual cursor (if not already active)
-- Used for building mode, map mode, etc.
function VirtualCursor.AutoEnable()
    if not STATE.cursor_mode_active then
        VirtualCursor.ToggleCursorMode(true, true)  -- Enable with auto_activate=true
    end
end

-- Auto-disable virtual cursor (only if it was auto-activated)
function VirtualCursor.AutoDisable()
    if STATE.cursor_mode_active and STATE.auto_activated then
        VirtualCursor.ToggleCursorMode(false)  -- Disable
    end
end


return VirtualCursor
