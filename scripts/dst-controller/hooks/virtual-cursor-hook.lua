-- Virtual Cursor Hook
-- Integrates virtual cursor with PlayerController

local G = require("dst-controller/global")
local VirtualCursor = require("dst-controller/virtual-cursor/core")
local CursorWidget = require("dst-controller/virtual-cursor/cursor_widget")
local Helpers = require("dst-controller/utils/helpers")

local VirtualCursorHook = {}

-- Track toggle combo state to prevent repeated toggles
local combo_was_pressed = false

-- Store original Input methods
local original_input_methods = {}

-- Hook TheInput to support virtual cursor
local function HookInputSystem()
    -- Note: TheSim:GetPosition hook is now managed dynamically in core.lua
    -- It's installed when cursor mode is activated and removed when deactivated
    -- This minimizes performance impact when virtual cursor is not in use

    -- Hook IsControlPressed to return button state for virtual cursor
    -- This is critical for drag detection (DST checks if CONTROL_PRIMARY is held)
    original_input_methods.IsControlPressed = G.TheInput.IsControlPressed
    G.TheInput.IsControlPressed = function(self, control)
        if VirtualCursor.IsCursorModeActive() then
            -- Check if it's primary/secondary control
            if control == G.CONTROL_PRIMARY then
                local button_states = VirtualCursor.GetButtonStates()
                return button_states.primary
            elseif control == G.CONTROL_SECONDARY then
                local button_states = VirtualCursor.GetButtonStates()
                return button_states.secondary
            end
        end
        return original_input_methods.IsControlPressed(self, control)
    end

    -- Hook ControllerAttached to return false when virtual cursor is active
    -- This is THE KEY to switching to mouse mode!
    -- When ControllerAttached() returns false, the entire game switches to mouse/keyboard mode
    original_input_methods.ControllerAttached = G.TheInput.ControllerAttached
    G.TheInput.ControllerAttached = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return false  -- Pretend no controller is attached → mouse mode
        end
        return original_input_methods.ControllerAttached(self)
    end

    -- Hook ClearCachedController to auto-close virtual cursor when pause menu opens
    -- When pause menu or other screens call ClearCachedController(), they want to switch to mouse mode
    -- We should close virtual cursor to avoid conflicts
    original_input_methods.ClearCachedController = G.TheInput.ClearCachedController
    G.TheInput.ClearCachedController = function(self)
        -- If virtual cursor is active, close it first
        if VirtualCursor.IsCursorModeActive() then
            Helpers.DebugPrint("Auto-closing virtual cursor (pause menu opened)")
            VirtualCursor.ToggleCursorMode()  -- Close cursor mode
        end
        -- Call original method
        return original_input_methods.ClearCachedController(self)
    end

    Helpers.DebugPrint("Virtual cursor hooks installed:")
    Helpers.DebugPrint("  ✓ IsControlPressed - for drag detection (RT/RB button states)")
    Helpers.DebugPrint("  ✓ ControllerAttached - returns false to enable mouse mode")
    Helpers.DebugPrint("  ✓ ClearCachedController - auto-close cursor when menu opens")
    Helpers.DebugPrint("  ⚡ TheSim:GetPosition - dynamically installed/removed on toggle")
    Helpers.DebugPrint("    ↳ Only active when virtual cursor is enabled")
    Helpers.DebugPrint("    ↳ Auto-fixes all Input position methods and hover detection")
end

function VirtualCursorHook.OnControl(self, control, down)
    -- Check for toggle combo (LB + RB + RT by default)
    -- Need to use raw input check because when cursor is active, ControllerAttached() returns false
    -- which might interfere with button detection
    local combo_config = VirtualCursor.GetConfig().toggle_combo or {"LB", "RB", "RT"}
    local combo_pressed = true

    -- Check each button in combo using TheSim directly (bypassing any hooks)
    for _, key_name in ipairs(combo_config) do
        local controls = G.BUTTON_MAPPINGS[key_name]
        local button_pressed = false
        if controls then
            for _, ctrl in ipairs(controls) do
                -- Use TheSim:GetDigitalControl directly - this bypasses all hooks
                if G.TheSim:GetDigitalControl(ctrl) then
                    button_pressed = true
                    break
                end
            end
        end
        if not button_pressed then
            combo_pressed = false
            break
        end
    end

    if combo_pressed and not combo_was_pressed then
        -- Combo just pressed, toggle cursor mode
        VirtualCursor.ToggleCursorMode()
        combo_was_pressed = true
        return true  -- Intercept
    elseif not combo_pressed then
        combo_was_pressed = false
    end

    -- If cursor mode is active, handle cursor controls
    if VirtualCursor.IsCursorModeActive() then
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
end


function VirtualCursorHook.Install()
    -- Hook Input system first
    HookInputSystem()

    -- Debug: Hook PlayerController to check OnUpdate conditions
    G.AddComponentPostInit("playercontroller", function(self)
        local old_OnUpdate = self.OnUpdate

        self.OnUpdate = function(pc_self, dt)
            -- Check conditions before calling original
            if VirtualCursor.IsCursorModeActive() then
                local current_time = G.GetTime and G.GetTime() or 0
                if not pc_self._debug_conditions_print then
                    pc_self._debug_conditions_print = 0
                end
                if current_time - pc_self._debug_conditions_print >= 0.5 then
                    local isenabled, ishudblocking = pc_self:IsEnabled()
                    local has_handler = pc_self.handler ~= nil
                    local actions_visible = pc_self.inst:IsActionsVisible()
                    local controller_attached = G.TheInput:ControllerAttached()
                    print(string.format("[VirtualCursor DEBUG] PC:OnUpdate conditions - enabled=%s, handler=%s, actionsVisible=%s, controllerAttached=%s",
                        tostring(isenabled),
                        tostring(has_handler),
                        tostring(actions_visible),
                        tostring(controller_attached)))
                    pc_self._debug_conditions_print = current_time
                end
            end

            return old_OnUpdate(pc_self, dt)
        end
    end)

    -- Debug: Hook playeractionpicker to see if DoGetMouseActions is ever called
    G.AddComponentPostInit("playeractionpicker", function(self)
        local old_DoGetMouseActions = self.DoGetMouseActions

        self.DoGetMouseActions = function(picker_self, ...)
            if VirtualCursor.IsCursorModeActive() then
                print("[VirtualCursor DEBUG] ===== DoGetMouseActions WAS CALLED! =====")
            end
            return old_DoGetMouseActions(picker_self, ...)
        end
    end)

    -- Hook into HUD to add cursor widget
    G.AddClassPostConstruct("widgets/controls", function(self)
        -- Create cursor widget and add to HUD
        local cursor_widget = self:AddChild(CursorWidget())
        cursor_widget:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
        cursor_widget:MoveToFront()  -- Ensure cursor is always on top

        -- Register widget with VirtualCursor core
        VirtualCursor.SetCursorWidget(cursor_widget)

        -- Store reference in playercontroller for updates
        if G.ThePlayer and G.ThePlayer.components.playercontroller then
            G.ThePlayer.components.playercontroller._cursor_widget = cursor_widget
        end
    end)

    -- Debug: Hook HoverText to see why it's not showing
    G.AddClassPostConstruct("widgets/hoverer", function(self)
        local old_OnUpdate = self.OnUpdate

        self.OnUpdate = function(hover_self)
            local result = old_OnUpdate(hover_self)

            -- Debug: Print hover text state occasionally
            if VirtualCursor.IsCursorModeActive() then
                local current_time = G.GetTime and G.GetTime() or 0
                if not hover_self._debug_last_print then
                    hover_self._debug_last_print = 0
                end
                if current_time - hover_self._debug_last_print >= 0.5 then
                    local pc = hover_self.owner.components.playercontroller
                    local using_mouse = pc and pc:UsingMouse() or false
                    local lmb_action = pc and pc:GetLeftMouseAction() or nil
                    print(string.format("[VirtualCursor DEBUG] HoverText - shown=%s, forcehide=%s, UsingMouse=%s, LMBaction=%s",
                        tostring(hover_self.shown),
                        tostring(hover_self.forcehide),
                        tostring(using_mouse),
                        lmb_action and lmb_action.action.id or "nil"))
                    hover_self._debug_last_print = current_time
                end
            end

            return result
        end
    end)
end

return VirtualCursorHook
