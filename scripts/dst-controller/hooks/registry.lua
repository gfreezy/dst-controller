-- Hook Registry
-- Central registry for all game hooks
-- Ensures each class/component is hooked exactly once

local G = require("dst-controller/global")

local HookRegistry = {}

-- Install all hooks in proper order
function HookRegistry.InstallAll()
    -- Install hooks in dependency order:
    -- 1. Input system hooks (lowest level - affects input detection)
    -- 2. PlayerController hooks (core gameplay)
    -- 3. HUD hooks (UI layer)
    -- 4. Inventory hooks (widget-specific)
    -- 5. Controls widget hooks (cursor widget injection)
    -- 6. Keyboard handlers (global hotkeys)

    print("[HookRegistry] Installing all hooks...")

    -- 1. Input System (TheInput global hooks)
    require("dst-controller/hooks/input-system-hook").Install()

    -- 2. PlayerController Component (button combinations, cursor integration)
    require("dst-controller/hooks/playercontroller-hook").Install()

    -- 3. PlayerHUD Class (blocks default actions when modifiers pressed)
    require("dst-controller/hooks/playerhud-hook").Install()

    -- 4. InventoryBar Widget (inventory behavior customization)
    require("dst-controller/hooks/inventorybar-hook").Install()

    -- 5. CraftingMenu Widget (hide bottom layer and block RSTICK)
    require("dst-controller/hooks/craftingmenu-hook").Install()

    -- 6. Controls Widget (cursor widget injection)
    require("dst-controller/hooks/controls-hook").Install()

    -- 7. MapScreen (path visualization on map)
    require("dst-controller/hooks/mapscreen-hook").Install()

    print("[HookRegistry] All hooks installed successfully")
end

return HookRegistry
