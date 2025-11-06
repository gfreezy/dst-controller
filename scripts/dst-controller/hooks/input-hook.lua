-- Enhanced Controller - Input Hook
-- Hooks TheInput to simulate keyboard key presses

local G = require("dst-controller/global")

local InputHook = {}

-- Virtual key states (key -> bool)
local virtual_key_states = {}

-- Hook IsKeyDown to return virtual key state
local function HookIsKeyDown()
    local old_IsKeyDown = G.TheInput.IsKeyDown

    G.TheInput.IsKeyDown = function(self, key)
        print("[InputHook] IsKeyDown", key)
        -- Check if we have a virtual state for this key
        if virtual_key_states[key] ~= nil then
            return virtual_key_states[key]
        end

        -- Otherwise return actual key state
        return old_IsKeyDown(self, key)
    end
end

-- Hook OnRawKey to trigger virtual key events
local function HookOnRawKey()
    local old_OnRawKey = G.TheInput.OnRawKey

    G.TheInput.OnRawKey = function(self, key, down)
        print("[InputHook] OnRawKey", key, down)
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
    virtual_key_states[key] = down

    -- Trigger the key event through OnRawKey
    -- This will call the event handlers just like a real key press
    G.TheInput:OnRawKey(key, down)

    -- Debug logging
    print(string.format("[InputHook] Simulated key %d: %s", key, down and "down" or "up"))
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

-- Get current virtual key states (for debugging)
function InputHook.GetVirtualKeyStates()
    return virtual_key_states
end

-- Install the hooks
function InputHook.Install()
    -- Wait for TheInput to be available
    if not G.TheInput then
        print("[InputHook] Warning: TheInput not available yet")
        return
    end

    HookIsKeyDown()
    HookOnRawKey()

    print("[InputHook] Input hooks installed")
end

return InputHook
