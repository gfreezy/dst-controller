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
    -- Hook GetWorldPosition to return virtual cursor position
    original_input_methods.GetWorldPosition = G.TheInput.GetWorldPosition
    G.TheInput.GetWorldPosition = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return VirtualCursor.GetCursorPosition()
        end
        return original_input_methods.GetWorldPosition(self)
    end

    -- Hook GetScreenPosition to return virtual cursor screen position
    original_input_methods.GetScreenPosition = G.TheInput.GetScreenPosition
    G.TheInput.GetScreenPosition = function(self)
        if VirtualCursor.IsCursorModeActive() then
            local pos = VirtualCursor.GetCursorScreenPosition()
            return G.Vector3(pos.x, pos.y, 0)
        end
        return original_input_methods.GetScreenPosition(self)
    end

    -- Hook GetWorldXZWithHeight for strafing/aiming direction
    -- This is used by strafer component to calculate aim direction
    original_input_methods.GetWorldXZWithHeight = G.TheInput.GetWorldXZWithHeight
    G.TheInput.GetWorldXZWithHeight = function(self, height)
        if VirtualCursor.IsCursorModeActive() then
            local pos = VirtualCursor.GetCursorScreenPosition()
            local x, _, z = G.TheSim:ProjectScreenPos(pos.x, pos.y, height)
            return x, z
        end
        return original_input_methods.GetWorldXZWithHeight(self, height)
    end

    -- Hook GetWorldEntityUnderMouse to return entity under virtual cursor
    original_input_methods.GetWorldEntityUnderMouse = G.TheInput.GetWorldEntityUnderMouse
    G.TheInput.GetWorldEntityUnderMouse = function(self)
        if VirtualCursor.IsCursorModeActive() then
            return VirtualCursor.GetEntityAtCursor()
        end
        return original_input_methods.GetWorldEntityUnderMouse(self)
    end

    -- Hook GetHUDEntityUnderMouse for UI interactions (inventory, crafting, etc.)
    original_input_methods.GetHUDEntityUnderMouse = G.TheInput.GetHUDEntityUnderMouse
    G.TheInput.GetHUDEntityUnderMouse = function(self)
        if VirtualCursor.IsCursorModeActive() then
            local entities = VirtualCursor.GetEntitiesAtCursor()
            -- Return first UI entity (entities without Transform component)
            for _, ent in ipairs(entities) do
                if ent and not ent.Transform then
                    return ent
                end
            end
            return nil
        end
        return original_input_methods.GetHUDEntityUnderMouse(self)
    end

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

    Helpers.DebugPrint("Virtual cursor Input hooks installed:")
    Helpers.DebugPrint("  ✓ GetWorldPosition - returns virtual cursor world position")
    Helpers.DebugPrint("  ✓ GetScreenPosition - returns virtual cursor screen position")
    Helpers.DebugPrint("  ✓ GetWorldXZWithHeight - for strafing/aiming direction")
    Helpers.DebugPrint("  ✓ GetWorldEntityUnderMouse - returns entity at virtual cursor")
    Helpers.DebugPrint("  ✓ GetHUDEntityUnderMouse - returns UI entity at virtual cursor")
    Helpers.DebugPrint("  ✓ IsControlPressed - returns virtual button states for drag detection")
end

function VirtualCursorHook.Install()
    -- Hook Input system first
    HookInputSystem()
    -- Hook into PlayerController
    G.AddComponentPostInit("playercontroller", function(self)
        -- Hook UsingMouse to return true when virtual cursor is active
        local old_UsingMouse = self.UsingMouse
        self.UsingMouse = function(self)
            if VirtualCursor.IsCursorModeActive() then
                return true  -- Pretend we're using mouse
            end
            return old_UsingMouse(self)
        end

        -- Store original OnControl
        local old_OnControl = self.OnControl

        -- Override OnControl
        self.OnControl = function(self, control, down)
            -- Check for toggle combo (LB + RB + RT by default)
            local combo_pressed = VirtualCursor.IsToggleComboPressed()

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
                    return old_OnControl(self, control, down)
                end

                -- LB not pressed: right stick controls cursor
                -- Note: We'll handle stick input in OnUpdate, not in OnControl
                -- because OnControl only fires on button edges, not continuous input
            end

            -- Call original OnControl
            return old_OnControl(self, control, down)
        end

        -- Store original OnUpdate
        local old_OnUpdate = self.OnUpdate

        -- Override OnUpdate to handle continuous right stick input
        self.OnUpdate = function(self, dt)
            -- Update hover entity detection (for hover text)
            VirtualCursor.UpdateHoverEntity()

            -- If cursor mode is active, update cursor position from right stick
            if VirtualCursor.IsCursorModeActive() then
                -- Check if LB is pressed
                local lb_pressed = G.TheInput:IsControlPressed(G.CONTROL_ROTATE_LEFT)

                -- Only move cursor if LB is NOT pressed
                if not lb_pressed then
                    -- Read right stick input
                    local stick_x = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_RIGHT)
                                  - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_LEFT)
                    local stick_y = G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_UP)
                                  - G.TheInput:GetAnalogControlValue(G.CONTROL_PRESET_RSTICK_DOWN)

                    -- Update cursor position
                    VirtualCursor.UpdateCursorPosition(dt, stick_x, stick_y)

                    -- Update cursor widget drag state
                    if self._cursor_widget then
                        self._cursor_widget:UpdateDragState(VirtualCursor.IsDragging())
                    end
                end
            end

            -- Call original OnUpdate
            return old_OnUpdate(self, dt)
        end

        Helpers.DebugPrint("Virtual cursor hook installed")
        Helpers.DebugPrint("  Toggle: LB + RB + RT (default)")
        Helpers.DebugPrint("  Right stick: Move cursor (when LB not pressed)")
        Helpers.DebugPrint("  LB + Right stick: Camera control")
    end)

    -- Hook into HUD to add cursor widget and control hover text
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

        -- Hook to show/hide hover text based on virtual cursor mode
        -- The hover widget already exists in controls (created by DST)
        if self.hover then
            -- Store original OnUpdate
            local old_hover_OnUpdate = self.hover.OnUpdate

            -- Override to show hover text when virtual cursor is active
            self.hover.OnUpdate = function(hover_self)
                -- If virtual cursor is active, show hover text
                if VirtualCursor.IsCursorModeActive() then
                    hover_self:Show()
                    -- Call original update (it will get virtual cursor position from our hooks)
                    old_hover_OnUpdate(hover_self)
                else
                    -- Original behavior (hide for gamepad, show for mouse)
                    old_hover_OnUpdate(hover_self)
                end
            end

            Helpers.DebugPrint("Virtual cursor hover text hook installed")
        end

        Helpers.DebugPrint("Virtual cursor widget created and added to HUD")
    end)
end

return VirtualCursorHook
