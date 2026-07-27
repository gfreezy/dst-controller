-- Virtual Cursor Core Module
-- Provides virtual cursor functionality with gamepad controls

local G = require("dst-controller/global")
local ConfigManager = require("dst-controller/utils/config_manager")
local Helpers = require("dst-controller/utils/helpers")
local ActionHelpers = require("dst-controller/actions/helpers")
local Motion = require("dst-controller/virtual-cursor/motion")
local Magnetism = require("dst-controller/virtual-cursor/magnetism")

local VirtualCursor = {}

-- Constants (inspired by dst-mod khy_fs.lua)
local BASE_SPEED_DIVISOR = 80  -- Longest screen edge / divisor = pixels per frame at 60fps
local SPEED_RATE_DEFAULT = 8  -- Lower full-stick speed without changing fine-control response
local STICK_RESPONSE_EXPONENT = 2.4  -- Preserve tiny input while making low/mid travel more precise
local STICK_RESPONSE_RATE = 30
local MAX_CURSOR_DELTA_TIME = 0.05
local INTERACTION_SAMPLE_GRID = 7
local INTERACTION_SAMPLE_PADDING = 0
local INTERACTION_SAMPLE_MAX_SPAN = 260

-- Scene-specific speed multipliers
local SPEED_MULTIPLIERS = {
    NORMAL = 1.0,           -- Normal movement
    UI_HOVER = 0.4,         -- Hovering over UI elements (ui_slow_rate)
    ENTITY_HOVER = 0.65,    -- Hovering over entities (slow_rate)
    BUILDING = 0.6,         -- Fast at full deflection; response curve preserves precision
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
    smoothed_stick_intensity = 0,
    dispatching_input_position = false,
    physical_mouse_active = false,

    -- Magnetism state
    tracking_target = nil,  -- Current magnetism target entity
    idle_state = false,  -- Whether the stick is inside the configured dead zone
    idle_wait_time = 0,  -- Time since stick became idle
    magnetism_scan_age = Magnetism.SCAN_INTERVAL,
    interaction_target = nil,
    interaction_offset_x = 0,
    interaction_offset_y = 0,
    interaction_sampled = false,
    interaction_use_origin = false,
    interaction_camera_heading = nil,
    interaction_camera_distance = nil,
    ui_tracking_widget = nil,  -- Current HUD widget magnetism target
    ui_idle_state = false,
    ui_idle_wait_time = 0,
    magnetism_suppressors = {},  -- Named temporary suppressors (drag selection, etc.)
    mode_blockers = {},  -- Screens that temporarily forbid cursor mode
}

local CONFIG_CACHE = {
    settings = nil,
    value = nil,
}

-- Helper function to get config with validation
local function GetConfig()
    local settings = ConfigManager.GetRuntimeSettings()
    if CONFIG_CACHE.settings == settings and CONFIG_CACHE.value ~= nil then
        return CONFIG_CACHE.value
    end

    local config = settings.virtual_cursor_settings or {}

    -- Validate and apply defaults
    local value = {
        enabled = config.enabled ~= false,  -- Default true
        toggle_combo = config.toggle_combo or {"LB", "RB", "RT"},
        left_click_key = "LT",
        right_click_key = "RT",
        cursor_speed = math.max(0.1, math.min(3.0, config.cursor_speed or 1.0)),  -- Clamp 0.1-3.0
        show_cursor = config.show_cursor ~= false,  -- Default true
        -- Magnetism settings
        cursor_magnetism = config.cursor_magnetism ~= false,  -- Default true
        magnetism_range = math.floor(math.max(1, math.min(3, config.magnetism_range or 2)) + 0.5),
        target_priority = config.target_priority == true,  -- Default false
    }
    CONFIG_CACHE.settings = settings
    CONFIG_CACHE.value = value
    return value
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
    Helpers.DebugPrintf("Cursor base speed: %.2f pixels/frame (screen: %dx%d)",
        STATE.base_cursor_speed, w, h)
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
        STATE.smoothed_stick_intensity = 0
        STATE.dispatching_input_position = false
        STATE.physical_mouse_active = false
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0
        STATE.magnetism_scan_age = Magnetism.SCAN_INTERVAL
        STATE.interaction_target = nil
        STATE.interaction_offset_x = 0
        STATE.interaction_offset_y = 0
        STATE.interaction_sampled = false
        STATE.interaction_use_origin = false
        STATE.interaction_camera_heading = nil
        STATE.interaction_camera_distance = nil
        STATE.ui_tracking_widget = nil
        STATE.ui_idle_state = false
        STATE.ui_idle_wait_time = 0
        STATE.magnetism_suppressors = {}

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

    if new_state and next(STATE.mode_blockers) ~= nil then
        return false
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

        Helpers.DebugPrintf("Cursor mode activated %s",
            STATE.auto_activated and "(auto)" or "(manual)")
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
            Helpers.DebugPrint("Cleared active item on cursor mode exit")
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
        STATE.smoothed_stick_intensity = 0
        STATE.dispatching_input_position = false
        STATE.physical_mouse_active = false
        STATE.tracking_target = nil
        STATE.idle_state = false
        STATE.idle_wait_time = 0
        STATE.magnetism_scan_age = Magnetism.SCAN_INTERVAL
        STATE.interaction_target = nil
        STATE.interaction_offset_x = 0
        STATE.interaction_offset_y = 0
        STATE.interaction_sampled = false
        STATE.interaction_use_origin = false
        STATE.interaction_camera_heading = nil
        STATE.interaction_camera_distance = nil
        STATE.ui_tracking_widget = nil
        STATE.ui_idle_state = false
        STATE.ui_idle_wait_time = 0
        STATE.magnetism_suppressors = {}

        -- Reset auto_activated flag
        STATE.auto_activated = false

        Helpers.DebugPrint("Cursor mode deactivated")
    end
    return true
end

-- Check if cursor mode is active
function VirtualCursor.IsCursorModeActive()
    return STATE.cursor_mode_active
end

-- Screens such as MapScreen use native controller focus and temporarily block
-- virtual cursor activation. Named blockers keep nested UI lifetimes safe.
function VirtualCursor.SetModeBlocked(source, blocked)
    if type(source) ~= "string" or source == "" then
        return
    end
    if blocked then
        STATE.mode_blockers[source] = true
        if STATE.cursor_mode_active then
            VirtualCursor.ToggleCursorMode(false)
        end
    else
        STATE.mode_blockers[source] = nil
    end
end

function VirtualCursor.IsModeBlocked()
    return next(STATE.mode_blockers) ~= nil
end

-- Temporarily suppress entity magnetism for interactions that require an exact
-- drag path (for example ActionQueue's rectangular selection). Named sources
-- avoid one integration accidentally re-enabling magnetism for another.
function VirtualCursor.SetMagnetismSuppressed(source, suppressed)
    if type(source) ~= "string" or source == "" then
        return
    end

    if suppressed then
        STATE.magnetism_suppressors[source] = true
    else
        STATE.magnetism_suppressors[source] = nil
    end

    STATE.tracking_target = nil
    STATE.idle_state = false
    STATE.idle_wait_time = 0
    STATE.magnetism_scan_age = Magnetism.SCAN_INTERVAL
    STATE.interaction_target = nil
    STATE.interaction_offset_x = 0
    STATE.interaction_offset_y = 0
    STATE.interaction_sampled = false
    STATE.interaction_use_origin = false
    STATE.interaction_camera_heading = nil
    STATE.interaction_camera_distance = nil
    STATE.ui_tracking_widget = nil
    STATE.ui_idle_state = false
    STATE.ui_idle_wait_time = 0
end

function VirtualCursor.IsMagnetismSuppressed()
    return next(STATE.magnetism_suppressors) ~= nil
end

function VirtualCursor.SetCursorPosition(x, y)
    if not STATE.cursor_mode_active then
        return
    end
    STATE.cursor_screen_pos.x = x
    STATE.cursor_screen_pos.y = y
    VirtualCursor.UpdateWorldPosition()
end

-- Physical mouse movement should use DST's native cursor only. Keep the
-- virtual position synchronized for clicks, but hide our duplicate artwork
-- until the player deliberately moves the right stick again.
function VirtualCursor.OnPhysicalMouseMove(x, y)
    if not STATE.cursor_mode_active then
        return
    end

    STATE.physical_mouse_active = true
    VirtualCursor.SetCursorPosition(x, y)
    if STATE.cursor_widget ~= nil and STATE.cursor_widget.Hide ~= nil then
        STATE.cursor_widget:Hide()
    end
end

local function ResumeVirtualCursorDisplay(config)
    if not STATE.physical_mouse_active then
        return
    end

    STATE.physical_mouse_active = false
    if STATE.cursor_widget ~= nil and STATE.cursor_widget.Show ~= nil and config.show_cursor then
        STATE.cursor_widget:Show()
    end
end

function VirtualCursor.IsPhysicalMouseActive()
    return STATE.physical_mouse_active
end

-- InputSystemHook uses this to distinguish a physical mouse event from the
-- virtual cursor notifying DST about a position it has already applied.
function VirtualCursor.IsDispatchingInputPosition()
    return STATE.dispatching_input_position
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

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and
        value > -math.huge and value < math.huge
end

local function GetEntityVisualBB(entity)
    if entity.AnimState == nil or entity.AnimState.GetVisualBB == nil then
        return nil
    end

    local ok, min_x, min_y, max_x, max_y = pcall(
        entity.AnimState.GetVisualBB, entity.AnimState)
    if not ok or not IsFiniteNumber(min_x) or not IsFiniteNumber(min_y) or
        not IsFiniteNumber(max_x) or not IsFiniteNumber(max_y) or
        max_x < min_x or max_y < min_y then
        return nil
    end
    return min_x, min_y, max_x, max_y
end

local function GetCameraRightVector()
    local camera = G.TheCamera
    if camera ~= nil and camera.GetRightVec ~= nil then
        local ok, right = pcall(camera.GetRightVec, camera)
        if ok and right ~= nil then
            return right.x or 0, right.z or 0
        end
    end
    return 1, 0
end

-- Aim at the centre of the currently drawn animation instead of the entity
-- origin (which is usually at its feet). GetVisualBB returns local visual
-- min/max coordinates with AnimState scaling already applied.
local function GetEntityVisualCenter(entity)
    local x, y, z = entity.Transform:GetWorldPosition()
    local center_x, center_y = 0, nil

    local min_x, min_y, max_x, max_y = GetEntityVisualBB(entity)
    if min_x ~= nil then
        center_x = (min_x + max_x) * 0.5
        center_y = (min_y + max_y) * 0.5
    end

    -- A few entities do not have an AnimState on the client. Their collision
    -- radius gives a conservative centre-above-ground fallback.
    if center_y == nil then
        local ok, radius = false, 0
        if entity.GetPhysicsRadius ~= nil then
            ok, radius = pcall(entity.GetPhysicsRadius, entity, 0)
        end
        center_y = ok and IsFiniteNumber(radius) and math.max(0, radius) or 0
    end

    -- Anim art is camera-facing, so its local X axis follows the camera's
    -- right vector rather than the world's X axis when the camera rotates.
    if center_x ~= 0 then
        local right_x, right_z = GetCameraRightVector()
        x = x + right_x * center_x
        z = z + right_z * center_x
    end

    return x, y + center_y, z
end

-- Get the visual centre's screen position from an entity.
function VirtualCursor.GetScreenPointFromEntity(entity)
    if not entity or not entity:IsValid() or entity.Transform == nil then
        return nil
    end

    local x, y, z = GetEntityVisualCenter(entity)
    local screen_x, screen_y = G.TheSim:GetScreenPos(x, y, z)

    if screen_x and screen_y then
        local screen_w, screen_h = G.TheSim:GetScreenSize()
        if screen_x >= 0 and screen_x <= screen_w and screen_y >= 0 and screen_y <= screen_h then
            return {x = screen_x, y = screen_y}
        end
    end

    return nil
end

local function GetEntityOriginScreenPoint(entity)
    if entity == nil or entity.Transform == nil then
        return nil
    end
    local world_x, world_y, world_z = entity.Transform:GetWorldPosition()
    local screen_x, screen_y = G.TheSim:GetScreenPos(world_x, world_y, world_z)
    if not IsFiniteNumber(screen_x) or not IsFiniteNumber(screen_y) then
        return nil
    end
    return {x = screen_x, y = screen_y}
end

local function IncludeScreenPoint(bounds, world_x, world_y, world_z)
    local screen_x, screen_y = G.TheSim:GetScreenPos(world_x, world_y, world_z)
    if not IsFiniteNumber(screen_x) or not IsFiniteNumber(screen_y) then
        return
    end
    bounds.min_x = math.min(bounds.min_x, screen_x)
    bounds.min_y = math.min(bounds.min_y, screen_y)
    bounds.max_x = math.max(bounds.max_x, screen_x)
    bounds.max_y = math.max(bounds.max_y, screen_y)
end

-- Get a conservative screen rectangle that contains either a billboard or a
-- ground-oriented animation. DST exposes SetOrientation but no corresponding
-- getter, so both projections are included before the actual hit test narrows
-- the result down.
local function GetInteractionSampleBounds(entity, approximate)
    local origin_x, origin_y, origin_z = entity.Transform:GetWorldPosition()
    local bounds = {
        min_x = approximate.x,
        min_y = approximate.y,
        max_x = approximate.x,
        max_y = approximate.y,
    }
    IncludeScreenPoint(bounds, origin_x, origin_y, origin_z)

    local min_x, min_y, max_x, max_y = GetEntityVisualBB(entity)
    if min_x ~= nil then
        local right_x, right_z = GetCameraRightVector()
        local down_x, down_z = nil, nil
        local camera = G.TheCamera
        if camera ~= nil and camera.GetDownVec ~= nil then
            local ok, down = pcall(camera.GetDownVec, camera)
            if ok and down ~= nil then
                down_x, down_z = down.x or 0, down.z or 0
            end
        end

        for _, local_x in ipairs({min_x, max_x}) do
            for _, local_y in ipairs({min_y, max_y}) do
                -- Billboard projection.
                IncludeScreenPoint(bounds,
                    origin_x + right_x * local_x,
                    origin_y + local_y,
                    origin_z + right_z * local_x)

                -- Ground-plane projection for dropped/flat art.
                if down_x ~= nil then
                    IncludeScreenPoint(bounds,
                        origin_x + right_x * local_x + down_x * local_y,
                        origin_y,
                        origin_z + right_z * local_x + down_z * local_y)
                end
            end
        end
    else
        bounds.min_x = bounds.min_x - 16
        bounds.min_y = bounds.min_y - 16
        bounds.max_x = bounds.max_x + 16
        bounds.max_y = bounds.max_y + 16
    end

    local center_x = (bounds.min_x + bounds.max_x) * 0.5
    local center_y = (bounds.min_y + bounds.max_y) * 0.5
    local width = math.max(12, bounds.max_x - bounds.min_x +
        INTERACTION_SAMPLE_PADDING * 2)
    local height = math.max(12, bounds.max_y - bounds.min_y +
        INTERACTION_SAMPLE_PADDING * 2)
    width = math.min(width, INTERACTION_SAMPLE_MAX_SPAN)
    height = math.min(height, INTERACTION_SAMPLE_MAX_SPAN)

    local screen_w, screen_h = G.TheSim:GetScreenSize()
    return {
        min_x = math.max(0, center_x - width * 0.5),
        min_y = math.max(0, center_y - height * 0.5),
        max_x = math.min(screen_w, center_x + width * 0.5),
        max_y = math.min(screen_h, center_y + height * 0.5),
    }
end

local function ScreenHitMatchesTarget(hit, target)
    if hit == target then
        return true
    end
    if hit ~= nil and hit.client_forward_target == target then
        return true
    end
    return target.client_forward_target ~= nil and
        target.client_forward_target == hit
end

local function ScreenPointHitsTarget(target, screen_x, screen_y)
    if G.TheSim.GetEntitiesAtScreenPoint == nil then
        return false
    end
    local ok, entities = pcall(
        G.TheSim.GetEntitiesAtScreenPoint, G.TheSim, screen_x, screen_y)
    if not ok or type(entities) ~= "table" then
        return false
    end
    for _, hit in ipairs(entities) do
        if ScreenHitMatchesTarget(hit, target) then
            return true
        end
    end
    return false
end

-- Sample the engine's real mouse hit test only for the selected target. The
-- uniform hit-point centroid is more useful than the visual centre for art
-- with transparent space, shadows, offsets, or a ground orientation.
local function SampleInteractionCenter(target, approximate)
    if G.TheSim.GetEntitiesAtScreenPoint == nil then
        return nil
    end

    local bounds = GetInteractionSampleBounds(target, approximate)
    local width = bounds.max_x - bounds.min_x
    local height = bounds.max_y - bounds.min_y
    if width <= 0 or height <= 0 then
        return nil
    end

    local sum_x, sum_y, hit_count = 0, 0, 0
    local divisions = INTERACTION_SAMPLE_GRID - 1
    for row = 0, divisions do
        local screen_y = bounds.min_y + height * row / divisions
        for column = 0, divisions do
            local screen_x = bounds.min_x + width * column / divisions
            if ScreenPointHitsTarget(target, screen_x, screen_y) then
                sum_x = sum_x + screen_x
                sum_y = sum_y + screen_y
                hit_count = hit_count + 1
            end
        end
    end

    if hit_count == 0 then
        return nil
    end
    return {x = sum_x / hit_count, y = sum_y / hit_count}
end

local function GetCameraSignature()
    local camera = G.TheCamera
    if camera == nil then
        return nil, nil
    end

    local heading, distance = nil, nil
    if camera.GetHeading ~= nil then
        local ok, value = pcall(camera.GetHeading, camera)
        heading = ok and IsFiniteNumber(value) and value or nil
    end
    if camera.GetDistance ~= nil then
        local ok, value = pcall(camera.GetDistance, camera)
        distance = ok and IsFiniteNumber(value) and value or nil
    end
    return heading, distance
end

local function CameraProjectionChanged(heading, distance)
    local old_heading = STATE.interaction_camera_heading
    if heading ~= nil and old_heading ~= nil then
        local difference = math.abs((heading - old_heading + 180) % 360 - 180)
        if difference > 1 then
            return true
        end
    end

    local old_distance = STATE.interaction_camera_distance
    return distance ~= nil and old_distance ~= nil and
        math.abs(distance - old_distance) > math.max(0.1, old_distance * 0.02)
end

local function ResetInteractionPoint()
    STATE.interaction_target = nil
    STATE.interaction_offset_x = 0
    STATE.interaction_offset_y = 0
    STATE.interaction_sampled = false
    STATE.interaction_use_origin = false
    STATE.interaction_camera_heading = nil
    STATE.interaction_camera_distance = nil
end

-- Returns a cached real-hit centroid that follows ordinary camera panning by
-- storing its offset from the cheap visual centre. Expensive sampling can be
-- deferred until stick release; rotation and zoom invalidate the old offset.
function VirtualCursor.GetInteractionScreenPointFromEntity(
    entity, approximate, allow_sampling)
    approximate = approximate or VirtualCursor.GetScreenPointFromEntity(entity)
    if approximate == nil then
        return nil
    end
    allow_sampling = allow_sampling ~= false

    local heading, distance = GetCameraSignature()
    if STATE.interaction_target ~= entity or
        CameraProjectionChanged(heading, distance) then
        STATE.interaction_target = entity
        STATE.interaction_offset_x = 0
        STATE.interaction_offset_y = 0
        STATE.interaction_sampled = false
        STATE.interaction_use_origin = false
        STATE.interaction_camera_heading = heading
        STATE.interaction_camera_distance = distance
    end

    if allow_sampling and not STATE.interaction_sampled then
        local sampled = SampleInteractionCenter(entity, approximate)
        local origin = sampled ~= nil and GetEntityOriginScreenPoint(entity) or nil
        STATE.interaction_use_origin = origin ~= nil
        STATE.interaction_offset_x = origin ~= nil and sampled.x - origin.x or 0
        STATE.interaction_offset_y = origin ~= nil and sampled.y - origin.y or 0
        STATE.interaction_sampled = true
        STATE.interaction_camera_heading = heading
        STATE.interaction_camera_distance = distance
    end

    local anchor = STATE.interaction_use_origin and
        GetEntityOriginScreenPoint(entity) or approximate
    if anchor == nil then
        return nil
    end
    local screen_x = anchor.x + STATE.interaction_offset_x
    local screen_y = anchor.y + STATE.interaction_offset_y
    local screen_w, screen_h = G.TheSim:GetScreenSize()
    if screen_x < 0 or screen_x > screen_w or
        screen_y < 0 or screen_y > screen_h then
        return nil
    end
    return {x = screen_x, y = screen_y}
end

local function ResetMagnetismTracking()
    STATE.tracking_target = nil
    STATE.idle_state = false
    STATE.idle_wait_time = 0
    STATE.magnetism_scan_age = Magnetism.SCAN_INTERVAL
    ResetInteractionPoint()
end

local function ResetUIMagnetismTracking()
    STATE.ui_tracking_widget = nil
    STATE.ui_idle_state = false
    STATE.ui_idle_wait_time = 0
end

local function GetUIWidgetScreenPoint(widget)
    if widget == nil or widget == STATE.cursor_widget or
        widget.GetWorldPosition == nil then
        return nil
    end

    if widget.inst ~= nil and widget.inst.IsValid ~= nil and
        not widget.inst:IsValid() then
        return nil
    end

    if widget.IsVisible ~= nil then
        local ok, visible = pcall(widget.IsVisible, widget)
        if not ok or not visible then
            return nil
        end
    end
    if widget.IsEnabled ~= nil then
        local ok, enabled = pcall(widget.IsEnabled, widget)
        if not ok or not enabled then
            return nil
        end
    end

    local ok, position = pcall(widget.GetWorldPosition, widget)
    if not ok or position == nil or
        not IsFiniteNumber(position.x) or not IsFiniteNumber(position.y) then
        return nil
    end

    local screen_w, screen_h = G.TheSim:GetScreenSize()
    if position.x < 0 or position.x > screen_w or
        position.y < 0 or position.y > screen_h then
        return nil
    end
    return {x = position.x, y = position.y}
end

-- The HUD entity under the pointer is often a button's child image. Walk to
-- the nearest focused ancestor so the target is the control centre rather
-- than an icon/text offset inside that control.
local function GetHoveredUIWidget()
    local input = G.TheInput
    if input == nil or input.GetHUDEntityUnderMouse == nil then
        return nil, nil, false
    end

    local hud_entity = input:GetHUDEntityUnderMouse()
    if hud_entity == nil then
        return nil, nil, false
    end

    local widget = hud_entity.widget
    if widget == nil then
        return nil, nil, true
    end

    local current = widget
    while current ~= nil and not current.is_screen do
        if current.focus and current.GetWorldPosition ~= nil then
            widget = current
            break
        end
        current = current.parent
    end

    return widget, GetUIWidgetScreenPoint(widget), true
end

-- UI magnetism deliberately acquires only a widget already under the pointer.
-- This centres inventory slots and buttons without repeatedly scanning the
-- entire widget tree or pulling the cursor across neighbouring controls.
-- Returns: assisted position or nil, and whether UI currently owns the cursor.
function VirtualCursor.UpdateUIMagnetismCursor(dt, is_idle, old_x, old_y,
    raw_x, raw_y, direction_x, direction_y, intensity)
    local config = GetConfig()
    local hovered_widget, hovered_pos, hud_under_cursor = GetHoveredUIWidget()

    if not config.cursor_magnetism or
       VirtualCursor.IsMagnetismSuppressed() or
       STATE.physical_mouse_active then
        ResetUIMagnetismTracking()
        return nil, hud_under_cursor
    end

    if hovered_widget ~= nil and hovered_pos ~= nil then
        STATE.ui_tracking_widget = hovered_widget
    end

    local target_pos = STATE.ui_tracking_widget ~= nil and
        GetUIWidgetScreenPoint(STATE.ui_tracking_widget) or nil
    if target_pos == nil then
        ResetUIMagnetismTracking()
        return nil, hud_under_cursor
    end

    if is_idle then
        if not STATE.ui_idle_state then
            STATE.ui_idle_state = true
            STATE.ui_idle_wait_time = 0
        end
        STATE.ui_idle_wait_time = STATE.ui_idle_wait_time + dt
    else
        STATE.ui_idle_state = false
        STATE.ui_idle_wait_time = 0
    end

    local screen_w, screen_h = G.TheSim:GetScreenSize()
    local acquire_radius = Magnetism.GetScreenRadius(
        config.magnetism_range, screen_w, screen_h)
    local dx = target_pos.x - old_x
    local dy = target_pos.y - old_y
    local distance = math.sqrt(dx * dx + dy * dy)
    local alignment = is_idle and 1 or
        Magnetism.GetAlignment(direction_x, direction_y, dx, dy)

    if Magnetism.ShouldRelease(
        distance, acquire_radius, is_idle, alignment, intensity) then
        ResetUIMagnetismTracking()
        return nil, hud_under_cursor
    end

    local new_x, new_y = Magnetism.ApplyAssist(
        old_x, old_y, raw_x, raw_y,
        target_pos.x, target_pos.y,
        acquire_radius, is_idle, STATE.ui_idle_wait_time,
        alignment, dt)
    return {x = new_x, y = new_y}, true
end

local function IsEntityAction(action, target)
    return action ~= nil and action.target == target
end

-- Return nil for decorative/non-actionable entities. An active inventory item
-- represents the strongest current intent, followed by scene actions and then
-- attackable targets.
local function GetInteractionPriority(target)
    local player = G.ThePlayer
    local controller = ActionHelpers.GetPlayerController(player)
    if controller == nil then
        return nil
    end

    if controller.GetCursorInventoryObject ~= nil and controller.GetItemUseAction ~= nil then
        local item_ok, active_item = pcall(controller.GetCursorInventoryObject, controller)
        if item_ok and active_item ~= nil then
            local action_ok, item_action = pcall(controller.GetItemUseAction,
                controller, active_item, target)
            if action_ok and IsEntityAction(item_action, target) then
                return 3
            end
        end
    end

    if controller.GetSceneItemControllerAction ~= nil then
        local action_ok, left_action, right_action = pcall(
            controller.GetSceneItemControllerAction, controller, target)
        if action_ok and
            (IsEntityAction(left_action, target) or IsEntityAction(right_action, target)) then
            return 2
        end
    end

    local combat = player and player.replica and player.replica.combat or nil
    if combat ~= nil and combat.CanTarget ~= nil then
        local combat_ok, can_target = pcall(combat.CanTarget, combat, target)
        if combat_ok and can_target then
            return 1
        end
    end

    return nil
end

local function IsUsableMagnetismTarget(target)
    if target == nil or target == G.ThePlayer or not target:IsValid() or
        target.entity == nil or not target.entity:IsVisible() then
        return false
    end
    for _, tag in ipairs(MAGNETISM_EXCLUDE_TAGS) do
        if target:HasTag(tag) then
            return false
        end
    end
    return G.CanEntitySeeTarget == nil or G.CanEntitySeeTarget(G.ThePlayer, target)
end

local function GetPlayerDistance(target)
    if target.GetDistanceSqToInst ~= nil then
        return math.sqrt(math.max(0, target:GetDistanceSqToInst(G.ThePlayer)))
    end
    local px, _, pz = G.ThePlayer.Transform:GetWorldPosition()
    local tx, _, tz = target.Transform:GetWorldPosition()
    local dx, dz = tx - px, tz - pz
    return math.sqrt(dx * dx + dz * dz)
end

-- Convert the screen-space assist circle to a conservative world-space query
-- radius. Candidate acceptance still uses exact screen pixels afterwards.
local function GetWorldSearch(center_x, center_y, screen_radius)
    local world_x, world_y, world_z = G.TheSim:ProjectScreenPos(center_x, center_y)
    if world_x == nil or world_z == nil then
        return nil
    end

    local world_radius = 0
    local offsets = {
        {screen_radius, 0}, {-screen_radius, 0},
        {0, screen_radius}, {0, -screen_radius},
    }
    for _, offset in ipairs(offsets) do
        local x, _, z = G.TheSim:ProjectScreenPos(center_x + offset[1], center_y + offset[2])
        if x ~= nil and z ~= nil then
            local dx, dz = x - world_x, z - world_z
            world_radius = math.max(world_radius, math.sqrt(dx * dx + dz * dz))
        end
    end

    world_radius = math.max(1.5, math.min(Magnetism.WORLD_SEARCH_MAX, world_radius * 1.35))
    return G.Vector3(world_x, world_y or 0, world_z), world_radius
end

local function FindBestMagnetismTarget(center_x, center_y, acquire_radius,
    is_idle, direction_x, direction_y, prefer_player)
    local search_center, world_radius = GetWorldSearch(center_x, center_y, acquire_radius)
    if search_center == nil then
        return nil
    end

    local entities = G.TheSim:FindEntities(
        search_center.x, search_center.y, search_center.z,
        world_radius, nil, MAGNETISM_EXCLUDE_TAGS)
    if STATE.tracking_target ~= nil then
        table.insert(entities, 1, STATE.tracking_target)
    end

    local seen = {}
    local best_target, best_screen_pos, best_score = nil, nil, -math.huge
    for _, raw_entity in ipairs(entities) do
        local target = raw_entity.client_forward_target or raw_entity
        if not seen[target] and IsUsableMagnetismTarget(target) then
            seen[target] = true
            local screen_pos = VirtualCursor.GetScreenPointFromEntity(target)
            if screen_pos ~= nil then
                local is_locked = target == STATE.tracking_target
                if is_locked then
                    screen_pos = VirtualCursor.GetInteractionScreenPointFromEntity(
                        target, screen_pos, is_idle)
                end
                if screen_pos ~= nil then
                    local dx = screen_pos.x - center_x
                    local dy = screen_pos.y - center_y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    local alignment = is_idle and 1 or
                        Magnetism.GetAlignment(direction_x, direction_y, dx, dy)
                    local priority = GetInteractionPriority(target)
                    if priority ~= nil then
                        local player_distance = prefer_player and GetPlayerDistance(target) or nil
                        local score = Magnetism.ScoreCandidate(
                            distance, acquire_radius, alignment, is_idle,
                            priority, is_locked, prefer_player, player_distance)
                        if score ~= nil and score > best_score then
                            best_target = target
                            best_screen_pos = screen_pos
                            best_score = score
                        end
                    end
                end
            end
        end
    end

    return best_target, best_screen_pos
end

local function IsBuildingPlacementActive()
    local controller = ActionHelpers.GetPlayerController(G.ThePlayer)
    return controller ~= nil and
        (controller.placer ~= nil or controller.deployplacer ~= nil)
end

-- Update magnetism cursor position
-- Returns: new_screen_pos {x, y} or nil
function VirtualCursor.UpdateMagnetismCursor(dt, is_idle, old_x, old_y,
    raw_x, raw_y, direction_x, direction_y, intensity)
    local config = GetConfig()

    -- Magnetism targets world entities. It must not run on the full-map screen,
    -- where ProjectScreenPos refers to the world camera behind the map.
    local active_screen = G.TheFrontEnd and G.TheFrontEnd:GetActiveScreen() or nil
    local magnetism_blocked = active_screen ~= nil and active_screen.name == "MapScreen"
    local hud_under_cursor = G.TheInput ~= nil and
        G.TheInput.GetHUDEntityUnderMouse ~= nil and
        G.TheInput:GetHUDEntityUnderMouse() ~= nil

    if not config.cursor_magnetism or
       VirtualCursor.IsMagnetismSuppressed() or
       STATE.physical_mouse_active or
       magnetism_blocked or
       IsBuildingPlacementActive() or
       hud_under_cursor or
       not G.ThePlayer then
        ResetMagnetismTracking()
        return nil
    end

    if is_idle then
        if not STATE.idle_state then
            STATE.idle_state = true
            STATE.idle_wait_time = 0
        end
        STATE.idle_wait_time = STATE.idle_wait_time + dt
    else
        STATE.idle_state = false
        STATE.idle_wait_time = 0
    end

    local screen_w, screen_h = G.TheSim:GetScreenSize()
    local acquire_radius = Magnetism.GetScreenRadius(config.magnetism_range, screen_w, screen_h)
    local approximate_screen_pos = STATE.tracking_target ~= nil and
        VirtualCursor.GetScreenPointFromEntity(STATE.tracking_target) or nil
    local screen_pos = approximate_screen_pos ~= nil and
        VirtualCursor.GetInteractionScreenPointFromEntity(
            STATE.tracking_target, approximate_screen_pos, is_idle) or nil

    if screen_pos ~= nil then
        local dx = screen_pos.x - old_x
        local dy = screen_pos.y - old_y
        local distance = math.sqrt(dx * dx + dy * dy)
        local alignment = is_idle and 1 or
            Magnetism.GetAlignment(direction_x, direction_y, dx, dy)
        if Magnetism.ShouldRelease(distance, acquire_radius, is_idle, alignment, intensity) then
            STATE.tracking_target = nil
            ResetInteractionPoint()
            screen_pos = nil
            STATE.magnetism_scan_age = Magnetism.SCAN_INTERVAL
        end
    end

    STATE.magnetism_scan_age = STATE.magnetism_scan_age + dt
    if STATE.magnetism_scan_age >= Magnetism.SCAN_INTERVAL then
        STATE.magnetism_scan_age = 0
        STATE.tracking_target, screen_pos = FindBestMagnetismTarget(
            old_x, old_y, acquire_radius, is_idle,
            direction_x, direction_y, config.target_priority)
        if STATE.tracking_target ~= nil and screen_pos ~= nil then
            screen_pos = VirtualCursor.GetInteractionScreenPointFromEntity(
                STATE.tracking_target, screen_pos, is_idle)
        else
            ResetInteractionPoint()
        end
    elseif screen_pos == nil then
        return nil
    end

    if STATE.tracking_target == nil or screen_pos == nil then
        return nil
    end

    local dx = screen_pos.x - old_x
    local dy = screen_pos.y - old_y
    local alignment = is_idle and 1 or
        Magnetism.GetAlignment(direction_x, direction_y, dx, dy)
    local new_x, new_y = Magnetism.ApplyAssist(
        old_x, old_y, raw_x, raw_y,
        screen_pos.x, screen_pos.y,
        acquire_radius, is_idle, STATE.idle_wait_time,
        alignment, dt)
    return {x = new_x, y = new_y}
end

-- Update cursor position based on right stick input (optimized algorithm from dst-mod)
function VirtualCursor.UpdateCursorPositionDelta(dt, stick_x, stick_y)
    if not STATE.cursor_mode_active then
        return
    end

    local config = GetConfig()

    -- Do not add a mod-side dead zone. The game/driver input reaches the radial
    -- response curve unchanged, so even small non-zero stick values can move.
    -- The response curve still keeps small movement precise.
    local is_idle, direction_x, direction_y, target_intensity = Motion.ResolveStick(
        stick_x, stick_y, 0, STICK_RESPONSE_EXPONENT)
    local movement_dt = Motion.ClampDeltaTime(dt, MAX_CURSOR_DELTA_TIME)
    if is_idle then
        STATE.smoothed_stick_intensity = 0
    else
        ResumeVirtualCursorDisplay(config)
        STATE.smoothed_stick_intensity = Motion.SmoothIntensity(
            STATE.smoothed_stick_intensity,
            target_intensity,
            movement_dt,
            STICK_RESPONSE_RATE)
    end

    local old_x = STATE.cursor_screen_pos.x
    local old_y = STATE.cursor_screen_pos.y
    local new_x = old_x
    local new_y = old_y

    if not is_idle then
        local adjusted_speed = GetAdjustedCursorSpeed(dt, config)
        local speed_per_second = adjusted_speed * 60
        new_x = old_x + direction_x * speed_per_second * STATE.smoothed_stick_intensity * movement_dt
        new_y = old_y + direction_y * speed_per_second * STATE.smoothed_stick_intensity * movement_dt
    end

    -- HUD controls own magnetism whenever the pointer is over one. Otherwise
    -- the world-target policy applies; the two systems never pull at once.
    local magnetism_pos, ui_owns_cursor = VirtualCursor.UpdateUIMagnetismCursor(
        dt, is_idle, old_x, old_y, new_x, new_y,
        direction_x, direction_y, STATE.smoothed_stick_intensity)
    if ui_owns_cursor then
        ResetMagnetismTracking()
    else
        magnetism_pos = VirtualCursor.UpdateMagnetismCursor(
            dt, is_idle, old_x, old_y, new_x, new_y,
            direction_x, direction_y, STATE.smoothed_stick_intensity)
    end
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

        -- Apply the visual position exactly once. The following input calls
        -- notify DST's UI and position event channels; their hooks must not
        -- write the same virtual position back into the widget.
        VirtualCursor.UpdateWorldPosition()
        STATE.dispatching_input_position = true

        if G.TheInput and G.TheInput.OnMouseMove then
            G.TheInput:OnMouseMove(new_x, new_y, true)
        end

        if G.TheInput and G.TheInput.UpdatePosition then
            G.TheInput:UpdatePosition(new_x, new_y, true)
        end
        STATE.dispatching_input_position = false
        VirtualCursor.UpdateHoverState()
    end
end

-- Update the visible cursor from its authoritative screen position. World
-- projection is performed only by callers that actually consume world space;
-- doing it here added a costly unused projection to every cursor update.
function VirtualCursor.UpdateWorldPosition()
    if not STATE.cursor_screen_pos then
        return
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

    -- Controller navigation can retain a focused widget even while the pointer
    -- is over the world. Only a HUD entity actually under the pointer should
    -- block world magnetism and activate UI slowdown.
    if G.TheInput.GetHUDEntityUnderMouse ~= nil and
        G.TheInput:GetHUDEntityUnderMouse() ~= nil then
        STATE.is_hovering_ui = true
        return  -- UI takes priority over entities
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
