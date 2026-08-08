-- Enhanced Controller - Input Hook
-- Hooks TheInput to simulate keyboard key presses

local G = require("dst-controller/global")
local Helpers = require("dst-controller/utils/helpers")

local InputHook = {}

-- Virtual key states (key -> bool)
local virtual_key_states = {}
local virtual_modifier_sources = {}
local original_is_key_down = nil
local dispatching_virtual_modifier = false

local function UniqueKeys(...)
    local keys = {}
    local seen = {}
    for index = 1, select("#", ...) do
        local key = select(index, ...)
        if type(key) == "number" and not seen[key] then
            seen[key] = true
            table.insert(keys, key)
        end
    end
    return keys
end

local MODIFIER_KEYS = {
    shift = UniqueKeys(G.KEY_LSHIFT, G.KEY_RSHIFT, G.KEY_SHIFT),
    alt = UniqueKeys(G.KEY_LALT, G.KEY_RALT, G.KEY_ALT),
    ctrl = UniqueKeys(G.KEY_LCTRL, G.KEY_RCTRL, G.KEY_CTRL),
    cmd = UniqueKeys(G.KEY_LSUPER, G.KEY_RSUPER),
}

local KEY_TO_MODIFIER = {}
for modifier, keys in pairs(MODIFIER_KEYS) do
    for _, key in ipairs(keys) do
        KEY_TO_MODIFIER[key] = modifier
    end
end

local function IsVirtualModifierDown(modifier)
    for _, source_modifier in pairs(virtual_modifier_sources) do
        if source_modifier == modifier then
            return true
        end
    end
    return false
end

local function IsPhysicalModifierDown(modifier)
    if original_is_key_down == nil or G.TheInput == nil then
        return false
    end
    for _, key in ipairs(MODIFIER_KEYS[modifier] or {}) do
        if original_is_key_down(G.TheInput, key) then
            return true
        end
    end
    return false
end

local function DispatchModifierTransition(modifier, down)
    local representative = (MODIFIER_KEYS[modifier] or {})[1]
    if representative ~= nil and G.TheInput ~= nil and
       not IsPhysicalModifierDown(modifier) then
        dispatching_virtual_modifier = true
        G.TheInput:OnRawKey(representative, down)
        dispatching_virtual_modifier = false
    end
end

-- Hook IsKeyDown to return virtual key state
local function HookIsKeyDown()
    original_is_key_down = G.TheInput.IsKeyDown

    G.TheInput.IsKeyDown = function(self, key)
        Helpers.DebugPrintf("IsKeyDown: %s", tostring(key))
        local modifier = KEY_TO_MODIFIER[key]
        return virtual_key_states[key] == true or
            (modifier ~= nil and IsVirtualModifierDown(modifier)) or
            original_is_key_down(self, key)
    end
end

-- Hook OnRawKey to trigger virtual key events
local function HookOnRawKey()
    local old_OnRawKey = G.TheInput.OnRawKey

    G.TheInput.OnRawKey = function(self, key, down)
        Helpers.DebugPrintf("OnRawKey: %s, down: %s",
            tostring(key), tostring(down))
        local modifier = KEY_TO_MODIFIER[key]
        if not dispatching_virtual_modifier and modifier ~= nil and
           IsVirtualModifierDown(modifier) then
            -- The semantic key is already held by a shoulder source. Suppress
            -- duplicate physical transitions until that source releases; the
            -- final raw key-up will still be delivered in the correct order.
            return
        end
        -- Call original first
        old_OnRawKey(self, key, down)

        -- Note: We don't need to do anything special here
        -- The virtual key presses are handled by SimulateKeyPress below
    end
end

-- Simulate a key press/release
-- This function is called by the keyboard action to trigger virtual keys
function InputHook.SimulateKeyPress(key, down)
    if not G.TheInput then
        return
    end

    -- Update virtual key state
    virtual_key_states[key] = down and true or nil

    -- Trigger the key event through OnRawKey
    -- This will call the event handlers just like a real key press
    G.TheInput:OnRawKey(key, down)

    -- Debug logging
    Helpers.DebugPrintf("Simulated key %d: %s", key, down and "down" or "up")
end

-- Clear a specific virtual key state
function InputHook.ClearVirtualKey(key)
    virtual_key_states[key] = nil
end

-- Clear all virtual key states
function InputHook.ClearAllVirtualKeys()
    for key, _ in pairs(virtual_key_states) do
        virtual_key_states[key] = nil
    end
end

-- Hold a semantic modifier on behalf of a named input source. Multiple sources
-- can share the same modifier; a key-up is emitted only after the final source
-- releases it.
function InputHook.SetVirtualModifier(source, modifier, down)
    if type(source) ~= "string" or source == "" or MODIFIER_KEYS[modifier] == nil then
        return false
    end

    local previous = virtual_modifier_sources[source]
    local previous_was_down = previous ~= nil and IsVirtualModifierDown(previous)
    local next_was_down = IsVirtualModifierDown(modifier)

    if down then
        if previous == modifier then
            return true
        end
        if previous ~= nil then
            virtual_modifier_sources[source] = nil
            if previous_was_down and not IsVirtualModifierDown(previous) then
                DispatchModifierTransition(previous, false)
            end
        end
        virtual_modifier_sources[source] = modifier
        if not next_was_down then
            DispatchModifierTransition(modifier, true)
        end
    elseif previous ~= nil then
        virtual_modifier_sources[source] = nil
        if previous_was_down and not IsVirtualModifierDown(previous) then
            DispatchModifierTransition(previous, false)
        end
    end
    return true
end

function InputHook.ClearVirtualModifier(source)
    local modifier = virtual_modifier_sources[source]
    if modifier ~= nil then
        return InputHook.SetVirtualModifier(source, modifier, false)
    end
    return false
end

function InputHook.ClearAllVirtualModifiers()
    local sources = {}
    for source in pairs(virtual_modifier_sources) do
        table.insert(sources, source)
    end
    for _, source in ipairs(sources) do
        InputHook.ClearVirtualModifier(source)
    end
end

function InputHook.GetModifierForKey(key)
    return KEY_TO_MODIFIER[key]
end

function InputHook.IsVirtualModifierDown(modifier)
    return IsVirtualModifierDown(modifier)
end

function InputHook.GetVirtualModifierSources()
    return virtual_modifier_sources
end

-- Get current virtual key states (for debugging)
function InputHook.GetVirtualKeyStates()
    return virtual_key_states
end

function InputHook._ResetForTests()
    virtual_key_states = {}
    virtual_modifier_sources = {}
    original_is_key_down = nil
    dispatching_virtual_modifier = false
end

-- Install the hooks
function InputHook.Install()
    -- Wait for TheInput to be available
    if not G.TheInput then
        Helpers.DebugPrint("TheInput not available yet")
        return
    end

    HookIsKeyDown()
    HookOnRawKey()

    Helpers.DebugPrint("Input hooks installed")
end

return InputHook
