local module_names = {
    "dst-controller/global",
    "dst-controller/utils/map_path_drawer",
    "dst-controller/virtual-cursor/core",
    "dst-controller/utils/helpers",
    "dst-controller/utils/client_pathfinder",
    "dst-controller/wormhole-tracker/map_visualizer",
    "dst-controller/locations/map-visualizer",
    "dst-controller/locations/player-service",
    "dst-controller/screens/location-screen",
    "dst-controller/utils/map-navigation",
    "dst-controller/hooks/input-system-hook",
    "dst-controller/localization",
    "dst-controller/hooks/mapscreen-hook",
}
local original_modules = {}
for _, name in ipairs(module_names) do
    original_modules[name] = package.loaded[name]
end

local postconstruct
local pushed = {}
local controller_attached = true
local pressed = {}
local cursor_active = true
local cursor_blocked = false
local cursor_restored_as_auto
local navigation_target
local cleared_player_positions = 0
package.loaded["dst-controller/global"] = {
    AddClassPostConstruct = function(path, fn)
        assert(path == "screens/mapscreen")
        postconstruct = fn
    end,
    TheInput = {
        ControllerAttached = function() return controller_attached end,
        IsControlPressed = function(_, control) return pressed[control] == true end,
        GetAnalogControlValue = function() return 0 end,
        GetLocalizedControl = function(_, _, control)
            return "[" .. tostring(control) .. "]"
        end,
        GetLocalizedVirtualDirectionalControl = function()
            return "[rstick]"
        end,
    },
    TheFrontEnd = {
        PushScreen = function(_, screen) pushed[#pushed + 1] = screen end,
    },
    CONTROL_MAP_ZOOM_IN = 10,
    CONTROL_MAP_ZOOM_OUT = 11,
    CONTROL_OPEN_CRAFTING = 10,
    CONTROL_CAM_AND_INV_MODIFIER = 20,
    CONTROL_CONTROLLER_ACTION = 33,
    CONTROL_CANCEL = 44,
    STRINGS = { UI = { HELP = { BACK = "BACK" } } },
    TUNING = { CONTROLLER_DEADZONE_RADIUS = 0.2 },
}

local function NoopModule(extra)
    local module = extra or {}
    return setmetatable(module, {
        __index = function()
            return function() end
        end,
    })
end

package.loaded["dst-controller/utils/map_path_drawer"] = NoopModule()
package.loaded["dst-controller/virtual-cursor/core"] = NoopModule({
    IsCursorModeActive = function() return cursor_active end,
    IsAutoActivated = function() return false end,
    SetModeBlocked = function(_, blocked)
        cursor_blocked = blocked
        if blocked then
            cursor_active = false
        end
    end,
    ToggleCursorMode = function(enabled, auto)
        assert(not cursor_blocked,
            "MapScreen must unblock cursor mode before restoring it")
        cursor_active = enabled == true
        cursor_restored_as_auto = auto
    end,
})
package.loaded["dst-controller/utils/helpers"] = NoopModule({
    IsControlAnyOf = function(control, names)
        for _, name in ipairs(names) do
            if name == "RB" and control == 22 then
                return true
            elseif name == "LT" and control == 10 then
                return true
            elseif name == "RT" and control == 11 then
                return true
            end
        end
        return false
    end,
    IsControlNamedButton = function(control, name)
        return (name == "A" and control == 33) or
            (name == "LT" and control == 10)
    end,
    IsButtonPressed = function() return false end,
})
package.loaded["dst-controller/utils/client_pathfinder"] = NoopModule({
    IsActive = function() return false end,
})
package.loaded["dst-controller/wormhole-tracker/map_visualizer"] = NoopModule()
package.loaded["dst-controller/locations/map-visualizer"] = NoopModule()
package.loaded["dst-controller/locations/player-service"] = {
    ClearPositions = function()
        cleared_player_positions = cleared_player_positions + 1
    end,
}
package.loaded["dst-controller/utils/map-navigation"] = NoopModule({
    Start = function(x, z)
        navigation_target = { x = x, z = z }
        return true
    end,
})
package.loaded["dst-controller/hooks/input-system-hook"] = {
    IsControllerPhysicallyAttached = function()
        return controller_attached
    end,
    GetPhysicalControllerID = function() return 1 end,
}
package.loaded["dst-controller/localization"] = {
    L = function(key) return key end,
}
local created = {}
package.loaded["dst-controller/screens/location-screen"] = function(
    map_screen, on_closed, ignore_opening_release)
    local screen = {
        map_screen = map_screen,
        on_closed = on_closed,
        ignore_opening_release = ignore_opening_release,
    }
    created[#created + 1] = screen
    return screen
end

package.loaded["dst-controller/hooks/mapscreen-hook"] = nil
local MapScreenHook = require("dst-controller/hooks/mapscreen-hook")
MapScreenHook.Install()
assert(type(postconstruct) == "function")

local native_controls = 0
local native_zoom_calls = 0
local native_saw_cursor_active
local native_destroy_saw_cursor_active
local mapcontrols_hidden = 0
local mapcontrols_disabled = 0
local map_screen = {
    mapcontrols = {
        Hide = function() mapcontrols_hidden = mapcontrols_hidden + 1 end,
        Disable = function() mapcontrols_disabled = mapcontrols_disabled + 1 end,
    },
    OnBecomeActive = function()
        native_saw_cursor_active = cursor_active
    end,
    OnDestroy = function()
        native_destroy_saw_cursor_active = cursor_active
    end,
    minimap = {
        GetZoom = function() return 5 end,
        Offset = function() end,
        MapPosToWorldPos = function(_, x, y, z)
            assert(x == 0 and y == 0 and z == 0,
                "map navigation should convert the center reticle")
            return 123, 456
        end,
    },
    zoom_target = 5,
    zoom_old = 5,
    zoom_target_time = 0,
    DoZoomIn = function()
        native_zoom_calls = native_zoom_calls + 1
    end,
    DoZoomOut = function() end,
    OnUpdate = function(self)
        if pressed[10] then
            self.zoom_target = 4
            self.zoom_old = 5
            self.zoom_target_time = 0.1
            self:DoZoomIn(-1)
        end
    end,
    GetHelpText = function() return "native help" end,
    OnControl = function()
        native_controls = native_controls + 1
        return "native"
    end,
}
postconstruct(map_screen)

map_screen:OnBecomeActive()
assert(not cursor_active and cursor_blocked and
    native_saw_cursor_active == false,
    "opening the map must switch to native controller focus")
assert(mapcontrols_hidden == 1 and mapcontrols_disabled == 1,
    "mouse-only map controls created before activation must be hidden")

assert(map_screen:OnControl(33, true) == true and
    navigation_target.x == 123 and navigation_target.z == 456,
    "controller A should navigate to map center outside cursor mode")
navigation_target = nil
map_screen:OnControl(33, false)
assert(navigation_target == nil,
    "releasing A should not start navigation again")
local controller_help = map_screen:GetHelpText()
assert(controller_help:find("[20] + [rstick] MAP_HELP_CAMERA", 1, true) and
    controller_help:find("[10] MAP_HELP_OPEN_LOCATIONS", 1, true) and
    controller_help:find("[33] MAP_HELP_NAVIGATE", 1, true),
    "map help must show scheme 2 location and navigation controls")

map_screen:OnUpdate(0.016)
assert(not cursor_active,
    "updating the map must keep virtual cursor mode disabled")

assert(map_screen.enhanced_location_screen == nil and #pushed == 0,
    "the location window should be collapsed by default")
assert(map_screen.enhanced_location_button == nil,
    "MapScreen must not create a visible location button")
assert(map_screen:OnControl(10, true) == true and #pushed == 1,
    "LT should open the location window in native map mode")
assert(cleared_player_positions == 1,
    "opening the location window should clear cached player map positions")
assert(pushed[1] == map_screen.enhanced_location_screen and
    pushed[1].map_screen == map_screen and
    pushed[1].ignore_opening_release)
assert(map_screen:OnControl(10, false) == true and #pushed == 1,
    "releasing LT must not stack another location window")

pushed[1].on_closed(pushed[1])
assert(map_screen.enhanced_location_screen == nil)
assert(map_screen:OnControl(10, true) == true and #pushed == 2,
    "LT should reopen the location window after it was closed")
assert(cleared_player_positions == 2,
    "reopening the location window should start with fresh player positions")
assert(pushed[2] == map_screen.enhanced_location_screen and
    pushed[2].ignore_opening_release)
assert(map_screen:OnControl(10, false) == true and #pushed == 2,
    "releasing LT must not stack another location window")
pushed[2].on_closed(pushed[2])

pressed[10] = true
map_screen:OnUpdate(0.016)
assert(native_zoom_calls == 0 and map_screen.zoom_target == 5 and
    map_screen.zoom_target_time == 0,
    "held LT should not zoom or leave native zoom interpolation behind")

map_screen:OnUpdate(0.016)
assert(native_zoom_calls == 0,
    "native map zoom must remain blocked while a controller is attached")
pressed[10] = false

assert(map_screen:OnControl(99, false) == "native" and native_controls == 1,
    "ordinary map controls should still use the native handler")

map_screen:OnDestroy()
assert(cursor_active and not cursor_blocked and
    native_destroy_saw_cursor_active == false and
    cursor_restored_as_auto == false,
    "closing the map should restore the cursor state from before entry")

cursor_active = false
local disabled_cursor_states = {}
local disabled_cursor_map_screen = {
    OnBecomeActive = function()
        disabled_cursor_states.open = cursor_active
    end,
    OnDestroy = function()
        disabled_cursor_states.close = cursor_active
    end,
    minimap = {
        GetZoom = function() return 5 end,
        Offset = function() end,
    },
    zoom_target = 5,
    zoom_old = 5,
    zoom_target_time = 0,
    DoZoomIn = function() end,
    DoZoomOut = function() end,
    OnUpdate = function() end,
    OnControl = function() return false end,
}
postconstruct(disabled_cursor_map_screen)
disabled_cursor_map_screen:OnBecomeActive()
disabled_cursor_map_screen:OnUpdate(0.016)
disabled_cursor_map_screen:OnDestroy()
assert(cursor_active == false and disabled_cursor_states.open == false and
    disabled_cursor_states.close == false,
    "MapScreen should also preserve a disabled virtual cursor")

controller_attached = false
local keyboard_native_controls = 0
local keyboard_native_updates = 0
local keyboard_map_screen = {
    OnBecomeActive = function() end,
    OnDestroy = function() end,
    GetHelpText = function() return "keyboard help" end,
    minimap = {
        GetZoom = function() return 5 end,
        Offset = function() end,
    },
    DoZoomIn = function() end,
    DoZoomOut = function() end,
    OnUpdate = function()
        keyboard_native_updates = keyboard_native_updates + 1
    end,
    OnControl = function()
        keyboard_native_controls = keyboard_native_controls + 1
        return "keyboard native"
    end,
}
postconstruct(keyboard_map_screen)
keyboard_map_screen:OnBecomeActive()
keyboard_map_screen:OnUpdate(0.016)
assert(keyboard_map_screen:OnControl(10, true) == "keyboard native" and
       keyboard_native_controls == 1 and keyboard_native_updates == 1 and
       keyboard_map_screen:GetHelpText() == "keyboard help",
    "keyboard/mouse map mode must preserve native update, controls, and help")
keyboard_map_screen:OnDestroy()

for _, name in ipairs(module_names) do
    package.loaded[name] = original_modules[name]
end
