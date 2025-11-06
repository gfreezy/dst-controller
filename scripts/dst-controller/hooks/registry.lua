-- Hook Registry
-- Central registry for all game hooks
-- Ensures each class/component is hooked exactly once

local G = require("dst-controller/global")

local HookRegistry = {}

-- Install all hooks in proper order
function HookRegistry.InstallAll()
    -- Install hooks in dependency order:
    -- 1. TheFrontEnd hooks (global UI layer - virtual cursor)
    -- 2. Input system hooks (lowest level - affects input detection)
    -- 3. PlayerController hooks (core gameplay)
    -- 4. HUD hooks (UI layer)
    -- 5. Inventory hooks (widget-specific)
    -- 6. Controls widget hooks (cursor widget injection)
    -- 7. Screen hooks (specific screen behaviors)

    print("[HookRegistry] Installing all hooks...")

    -- 1. TheFrontEnd (global UI - virtual cursor updates and controls)
    require("dst-controller/hooks/thefrontend-hook").Install()

    -- 2. Input System (TheInput global hooks)
    require("dst-controller/hooks/input-system-hook").Install()

    -- 2b. Input Hook (keyboard simulation via IsKeyDown and OnRawKey)
    require("dst-controller/hooks/input-hook").Install()

    -- 3. PlayerController Component (button combinations, pathfinding updates)
    require("dst-controller/hooks/playercontroller-hook").Install()

    -- 4. PlayerHUD Class (task config shortcut)
    require("dst-controller/hooks/playerhud-hook").Install()

    -- 5. InventoryBar Widget (inventory behavior customization)
    require("dst-controller/hooks/inventorybar-hook").Install()

    -- 6. CraftingMenu Widget (hide bottom layer and block RSTICK)
    require("dst-controller/hooks/craftingmenu-hook").Install()

    -- 7. Controls Widget (cursor widget injection)
    require("dst-controller/hooks/controls-hook").Install()

    -- 8. MapScreen (path visualization and click-to-walk)
    require("dst-controller/hooks/mapscreen-hook").Install()

    print("[HookRegistry] All hooks installed successfully")
end

return HookRegistry
