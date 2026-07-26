local find_calls = 0
local screen_hit_calls = 0
local hud_entity = nil
local controller = {}
local player

local function MakeEntity(name, screen_x, screen_y, actionable, visual_bb)
    local entity = {
        name = name,
        actionable = actionable,
        entity = {
            IsVisible = function() return true end,
        },
    }
    entity.Transform = {
        GetWorldPosition = function()
            return screen_x / 10, 0, screen_y / 10
        end,
    }
    if visual_bb ~= nil then
        entity.AnimState = {
            GetVisualBB = function()
                return visual_bb[1], visual_bb[2], visual_bb[3], visual_bb[4]
            end,
        }
    end
    function entity:IsValid() return true end
    function entity:HasTag() return false end
    return entity
end

local decorative = MakeEntity("decorative", 106, 100, false)
local actionable_visual_bb = {-2, 0, 4, 6}
local actionable = MakeEntity("actionable", 130, 100, true, actionable_visual_bb)

function controller:GetCursorInventoryObject()
    return nil
end

function controller:GetSceneItemControllerAction(target)
    if target.actionable then
        return { target = target }, nil
    end
end

player = {
    components = { playercontroller = controller },
    replica = {
        combat = {
            CanTarget = function() return false end,
        },
    },
    Transform = {
        GetWorldPosition = function() return 0, 0, 0 end,
    },
}

local settings = {
    virtual_cursor_settings = {
        cursor_speed = 1,
        dead_zone = 0.2,
        cursor_magnetism = true,
        magnetism_range = 2,
        target_priority = false,
    },
}

package.loaded["dst-controller/global"] = {
    ThePlayer = player,
    TheFrontEnd = {
        GetActiveScreen = function() return nil end,
        GetFocusWidget = function() return {} end,
    },
    TheCamera = {
        GetRightVec = function()
            return {x = 1, y = 0, z = 0}
        end,
    },
    TheInput = {
        OnMouseMove = function() end,
        UpdatePosition = function() end,
        GetHUDEntityUnderMouse = function() return hud_entity end,
    },
    TheSim = {
        GetScreenSize = function() return 1920, 1080 end,
        ProjectScreenPos = function(_, screen_x, screen_y)
            return screen_x / 10, 0, screen_y / 10
        end,
        GetScreenPos = function(_, world_x, world_y, world_z)
            return world_x * 10, (world_y + world_z) * 10
        end,
        GetEntitiesAtScreenPoint = function(_, screen_x, screen_y)
            screen_hit_calls = screen_hit_calls + 1
            if screen_x >= 145 and screen_x <= 165 and
                screen_y >= 100 and screen_y <= 120 then
                return {actionable}
            end
            return {}
        end,
        FindEntities = function()
            find_calls = find_calls + 1
            return {decorative, actionable}
        end,
    },
    Vector3 = function(x, y, z)
        return {x = x, y = y, z = z}
    end,
    CanEntitySeeTarget = function() return true end,
}
package.loaded["dst-controller/utils/config_manager"] = {
    GetRuntimeSettings = function() return settings end,
}
package.loaded["dst-controller/utils/helpers"] = {}
package.loaded["dst-controller/actions/helpers"] = {
    GetPlayerController = function() return controller end,
}
package.loaded["dst-controller/virtual-cursor/core"] = nil

local VirtualCursor = require("dst-controller/virtual-cursor/core")
local state = VirtualCursor.GetState()
state.cursor_mode_active = true
state.cursor_screen_pos.x = 100
state.cursor_screen_pos.y = 100
state.base_cursor_speed = 20

VirtualCursor.UpdateHoverState()
assert(not state.is_hovering_ui,
    "a retained controller focus widget must not block world magnetism")
hud_entity = {}
VirtualCursor.UpdateHoverState()
assert(state.is_hovering_ui, "a HUD entity under the pointer must block world magnetism")
hud_entity = nil
VirtualCursor.UpdateHoverState()

local visual_center = VirtualCursor.GetScreenPointFromEntity(actionable)
assert(visual_center.x == 140 and visual_center.y == 130,
    "world magnetism must project the current animation's visual centre")
local interaction_center = VirtualCursor.GetInteractionScreenPointFromEntity(
    actionable, visual_center)
assert(interaction_center.x == 155 and interaction_center.y == 110,
    "world magnetism must use the centroid of the engine's real hit region")
assert(screen_hit_calls == 49,
    "the selected target must use one bounded 7x7 interaction sample")
VirtualCursor.GetInteractionScreenPointFromEntity(actionable, visual_center)
assert(screen_hit_calls == 49,
    "the interaction-region centre must be cached while projection is stable")
actionable_visual_bb[1], actionable_visual_bb[2] = -1, 1
actionable_visual_bb[3], actionable_visual_bb[4] = 5, 7
local animated_visual_center = VirtualCursor.GetScreenPointFromEntity(actionable)
local stable_interaction_center = VirtualCursor.GetInteractionScreenPointFromEntity(
    actionable, animated_visual_center)
assert(stable_interaction_center.x == 155 and stable_interaction_center.y == 110,
    "animation bounds must not move a sampled interaction centre")
assert(screen_hit_calls == 49,
    "animation-only visual changes must not trigger another hit sample")
actionable_visual_bb[1], actionable_visual_bb[2] = -2, 0
actionable_visual_bb[3], actionable_visual_bb[4] = 4, 6

local ui_widget = {
    focus = true,
    GetWorldPosition = function()
        return {x = 130, y = 100, z = 0}
    end,
    IsVisible = function() return true end,
    IsEnabled = function() return true end,
}
hud_entity = {widget = ui_widget}
VirtualCursor.UpdateCursorPositionDelta(1 / 60, 1, 0)
assert(state.ui_tracking_widget == ui_widget,
    "a HUD control under the pointer must become the UI magnetism target")
assert(state.cursor_screen_pos.x > 100,
    "UI magnetism must assist movement toward the control centre")
assert(find_calls == 0, "UI and world magnetism must not scan or pull together")
for _ = 1, 6 do
    VirtualCursor.UpdateCursorPositionDelta(0.1, 0, 0)
end
assert(state.cursor_screen_pos.x == 130 and state.cursor_screen_pos.y == 100,
    "an idle cursor over UI must settle exactly at the control centre")

VirtualCursor.SetMagnetismSuppressed("reset-ui-test", true)
VirtualCursor.SetMagnetismSuppressed("reset-ui-test", false)
hud_entity = nil
state.cursor_screen_pos.x = 100
state.cursor_screen_pos.y = 100
state.smoothed_stick_intensity = 0
VirtualCursor.UpdateHoverState()

VirtualCursor.UpdateCursorPositionDelta(1 / 60, 1, 0)
assert(state.tracking_target == actionable,
    "screen-space magnetism must ignore a closer decorative entity")
assert(find_calls == 1, "the first movement frame should acquire a target")
assert(screen_hit_calls == 49,
    "moving target acquisition must defer interaction sampling to avoid a frame spike")
VirtualCursor.UpdateCursorPositionDelta(0.1, 0, 0)
assert(screen_hit_calls == 98 and state.interaction_sampled,
    "stick release must sample the selected target exactly once")
assert(state.interaction_offset_x == 25 and state.interaction_offset_y == 10,
    "the cached interaction centre must be anchored to the stable entity origin")

VirtualCursor.SetMagnetismSuppressed("test", true)
VirtualCursor.UpdateCursorPositionDelta(1 / 60, 1, 0)
assert(state.tracking_target == nil, "an explicit suppressor must clear magnetism")
assert(find_calls == 2, "suppressed magnetism must not scan world entities")
VirtualCursor.SetMagnetismSuppressed("test", false)

controller.placer = {}
VirtualCursor.UpdateCursorPositionDelta(1 / 60, 1, 0)
assert(state.tracking_target == nil, "building placement must disable entity magnetism")
assert(find_calls == 2, "building placement must not scan magnetism candidates")
