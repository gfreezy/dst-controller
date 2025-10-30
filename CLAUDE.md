# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Don't Starve Together (DST) mod** that enhances gamepad/controller functionality with custom button combinations, camera controls, and in-game configuration UI. It's a client-only mod written in Lua using the DST Modding API (version 10).

**Version**: 2.0.0
**Author**: feichao

## DST Game Scripts Reference

The `scripts-raw/` directory contains the **original DST game interface and implementation files**. These are reference files for understanding DST's internal APIs and should NOT be modified. Use them to:
- Understand DST's control system ([scripts-raw/input.lua](scripts-raw/input.lua))
- Look up component APIs (scripts-raw/components/)
- Find control constants and mappings (scripts-raw/constants.lua)
- Understand how the game's internal systems work

When implementing mod features, reference these files to understand the game's behavior, but implement your mod logic in `scripts/dst-controller/`.

## Core Architecture

### Entry Points

- **modinfo.lua**: Mod metadata and configuration options (exposed in game UI)
- **modmain.lua**: Main entry point that initializes global environment and loads all hooks

### Directory Structure

```
dst-controller/
├── modinfo.lua                    # Mod metadata
├── modmain.lua                    # Entry point
├── scripts/
│   └── dst-controller/            # All mod code under this namespace
│       ├── global.lua             # Global references (G module)
│       ├── actions/               # Action implementations
│       │   ├── init.lua           # Action registry
│       │   ├── combat.lua         # Combat actions
│       │   ├── equipment.lua      # Equipment actions
│       │   ├── items.lua          # Item actions
│       │   ├── inspection.lua     # Inspection actions
│       │   ├── character.lua      # Character actions
│       │   ├── crafting.lua       # Crafting actions
│       │   ├── utility.lua        # Utility actions
│       │   └── helpers.lua        # Action helpers
│       ├── core/                  # Core logic
│       │   ├── button-handler.lua # Button combination detection
│       │   └── action-executor.lua # Action execution engine
│       ├── hooks/                 # Game hooks
│       │   ├── controller-hook.lua     # PlayerController hook
│       │   ├── hud-hook.lua            # HUD hook
│       │   ├── inventorybar-hook.lua   # Inventory bar hook
│       │   ├── target-hook.lua         # Target selection hook
│       │   ├── taskconfig-hook.lua     # Config UI hotkey hook
│       │   └── virtual-cursor-hook.lua # Virtual cursor integration
│       ├── screens/               # UI screens
│       │   └── taskconfig_screen.lua  # Config UI (3-layer)
│       ├── utils/                 # Utilities
│       │   ├── helpers.lua        # General helpers
│       │   └── config_manager.lua # Config persistence
│       ├── config/                # Configuration
│       │   └── tasks.lua          # Default button configurations
│       ├── target-selection/      # Target selection system
│       │   └── core.lua
│       └── virtual-cursor/        # Virtual cursor system
│           ├── core.lua           # Cursor logic and state
│           └── cursor_widget.lua  # Cursor visual widget
├── DST_MOUSE_BEHAVIOR_ANALYSIS.md # Mouse system analysis
└── scripts-raw/                   # DST reference files (read-only)
```

## Key Systems

### 1. Global References (G Module)

**File**: [scripts/dst-controller/global.lua](scripts/dst-controller/global.lua)

The `G` module provides centralized access to GLOBAL and env references:

```lua
local G = require("dst-controller/global")
G.Init(GLOBAL, env)  -- Called once in modmain.lua

-- Usage in other modules:
local G = require("dst-controller/global")
G.ThePlayer          -- Game objects (from GLOBAL)
G.TheInput           -- Input system
G.TUNING             -- Game parameters
G.AddComponentPostInit -- Mod API (from env)
```

**Why it exists**:
- GLOBAL and env are only accessible in modmain.lua
- Other modules need references to game objects and mod APIs
- Uses metatable for dynamic proxy (handles late-created objects like ThePlayer)

**Important**: All `require` paths use the `dst-controller/` namespace prefix.

### 2. Button Combination System

**Files**:
- [scripts/dst-controller/core/button-handler.lua](scripts/dst-controller/core/button-handler.lua)
- [scripts/dst-controller/hooks/controller-hook.lua](scripts/dst-controller/hooks/controller-hook.lua)

Supports 12 button combinations:
- LB + A/B/X/Y/LT/RT
- RB + A/B/X/Y/LT/RT

Each combination supports:
- `on_press`: Actions when combination is pressed
- `on_release`: Actions when combination is released
- Multiple actions in sequence
- Parameterized actions

### 3. In-Game Configuration UI

**Files**:
- [scripts/dst-controller/screens/taskconfig_screen.lua](scripts/dst-controller/screens/taskconfig_screen.lua)
- [scripts/dst-controller/hooks/taskconfig-hook.lua](scripts/dst-controller/hooks/taskconfig-hook.lua)

**Features**:
- 3-layer UI: Main screen → Detail screen → Action editor
- Full gamepad support (A/B for select/cancel, LB/RB for tab switching)
- 16 available actions with parameter support
- Real-time preview and editing
- Hotkeys:
  - Keyboard: `Ctrl+K`
  - Gamepad: `LB+RB+Y` (simultaneously)

**UI Flow**:
```
TaskConfigScreen (Main)
  → Shows 12 button combinations
  → Click to configure
    ↓
ActionDetailScreen (Detail)
  → Tabs: on_press / on_release
  → Action list with ↑↓ buttons for reordering
  → Add/Edit/Delete actions
    ↓
ActionEditorDialog (Editor)
  → Select action type (Spinner)
  → Select parameter (Spinner, conditional)
  → Confirm/Cancel
```

### 4. Configuration Persistence

**File**: [scripts/dst-controller/utils/config_manager.lua](scripts/dst-controller/utils/config_manager.lua)

Configuration is saved to: `client_save/enhanced_controller_config.json`

**Key Functions**:
- `LoadTasksFromFile(callback)` - Load saved config on startup
- `SaveTasksToFile(tasks, callback)` - Save config to file
- `GetRuntimeTasks()` - Get current runtime config
- `UpdateRuntimeTasks(tasks)` - Update runtime config (immediate effect)
- `LoadDefaultTasks()` - Fallback to default config

**Data Flow**:
```
Startup:
  LoadTasksFromFile → RUNTIME_TASKS cache
  ↓
Runtime:
  Controller hooks read from GetRuntimeTasks()
  ↓
Config UI:
  User edits → SaveTasksToFile + UpdateRuntimeTasks
  ↓
Next Startup:
  LoadTasksFromFile → loads saved config
```

### 5. Action System

**File**: [scripts/dst-controller/actions/init.lua](scripts/dst-controller/actions/init.lua)

Actions are organized by category:
- **Combat**: attack, force_attack
- **Inspection**: examine, inspect_self
- **Equipment**: equip_item, cycle_head/hand/body
- **Items**: use_item, use_item_on_self, save_hand_item, restore_hand_item
- **Crafting**: craft_item
- **Character**: (character-specific actions)
- **Utility**: start_channeling, stop_channeling

Each action module exports:
```lua
return {
    action_name = function(player, param)
        -- Implementation
    end,
    -- ...
}
```

### 6. Hook System

All hooks use `G.AddComponentPostInit` or `G.AddClassPostConstruct`:

**controller-hook.lua**: Intercepts `playercontroller:OnControl`
- Detects button combinations
- Executes configured actions
- Manages button state

**hud-hook.lua**: Modifies `playeractionpicker:OnControl`
- Blocks default actions when modifier keys (LB/RB) are held

**inventorybar-hook.lua**: Customizes inventory widget behavior
- Shows hints for equipped items
- Handles inventory navigation

**target-hook.lua**: Customizes target selection
- Supports 360° targeting (configurable)
- Hostile-only targeting (configurable)

**taskconfig-hook.lua**: Registers config UI hotkeys
- Keyboard: Ctrl+K
- Gamepad: LB+RB+Y

**virtual-cursor-hook.lua**: Integrates virtual cursor system
- Hooks Input methods (GetWorldPosition, GetScreenPosition, etc.)
- Hooks PlayerController:UsingMouse() to enable mouse mode
- Manages cursor widget visibility and updates

### 7. Virtual Cursor System

**Files**:
- [scripts/dst-controller/virtual-cursor/core.lua](scripts/dst-controller/virtual-cursor/core.lua)
- [scripts/dst-controller/virtual-cursor/cursor_widget.lua](scripts/dst-controller/virtual-cursor/cursor_widget.lua)
- [scripts/dst-controller/hooks/virtual-cursor-hook.lua](scripts/dst-controller/hooks/virtual-cursor-hook.lua)

**Purpose**: Provides mouse-like cursor control using gamepad right stick

**Key Features**:
- **Full Screen Coverage**: Cursor can move across entire screen (not limited to player vicinity)
- **Screen-based Movement**: Works directly in screen coordinates for natural feel
- **Automatic Bounds**: Clamped to visible screen area
- **HUD Integration**: Supports clicking on inventory, crafting menu, and all UI elements
- **Drag Walking**: Implements DST's 8-frame drag detection threshold
- **Hover Detection**: Shows hover text and entity highlights
- **Performance Optimized**: Rate-limited hover detection (updates only on >5 pixel movement)

**Toggle Control** (default):
- Keyboard: LB + RB + RT (simultaneously)
- Configurable in settings

**Cursor Movement**:
- Right stick: Move cursor (when LB not pressed)
- LB + Right stick: Camera control (original behavior)
- RT: Left-click
- RB: Right-click

**Configuration** (saved in `enhanced_controller_config.json`):
```lua
virtual_cursor_settings = {
    enabled = true,                    -- Enable/disable feature
    toggle_combo = {"LB", "RB", "RT"}, -- Button combination to toggle
    left_click_key = "RT",             -- Button for left-click
    right_click_key = "RB",            -- Button for right-click
    cursor_speed = 1.0,                -- Movement speed multiplier (0.1-3.0)
    dead_zone = 0.1,                   -- Stick dead zone (0.0-0.5)
    show_cursor = true,                -- Show/hide cursor widget
}
```

**Architecture**:
```
User Input (Right Stick)
    ↓
VirtualCursor.UpdateCursorPosition(dt, stick_x, stick_y)
    ↓
Update screen coordinates (clamped to screen bounds)
    ↓
VirtualCursor.UpdateWorldPosition()  -- Project to world coords
    ↓
VirtualCursor.UpdateHoverEntity()    -- Detect entities (rate-limited)
    ↓
Input Hooks return virtual cursor data:
  - TheInput:GetWorldPosition() → virtual cursor world pos
  - TheInput:GetScreenPosition() → virtual cursor screen pos
  - TheInput:GetWorldEntityUnderMouse() → entity at cursor
  - TheInput:GetHUDEntityUnderMouse() → UI element at cursor
  - PlayerController:UsingMouse() → true (enables mouse mode)
    ↓
DST's native mouse handling takes over
  - Hover text displays
  - Actions computed
  - Click/drag detection works normally
```

**Implementation Notes**:
- Cursor position stored in both screen coords and world coords
- Screen coords updated first, then projected to world coords
- All DST Input methods hooked to return virtual cursor data when active
- No modifications to DST's action/click/drag logic needed
- Fully compatible with existing mouse-based interactions

**Reference Documentation**:
See [DST_MOUSE_BEHAVIOR_ANALYSIS.md](DST_MOUSE_BEHAVIOR_ANALYSIS.md) for deep dive into DST's mouse system and implementation details.

## Development Guidelines

### Adding New Actions

1. Create action in appropriate module (e.g., `actions/combat.lua`)
2. Export from module
3. Register in `actions/init.lua`
4. Add to `AVAILABLE_ACTIONS` in `screens/taskconfig_screen.lua`
5. Add preset parameters to `ITEM_PRESETS` if needed

### Accessing Game Objects

Always use the `G` module:

```lua
local G = require("dst-controller/global")

-- ✅ Correct
G.ThePlayer
G.TheInput
G.AddComponentPostInit

-- ❌ Wrong
ThePlayer  -- Won't work (not in module scope)
GLOBAL.ThePlayer  -- Don't access GLOBAL directly
```

### Module Requires

All requires use the `dst-controller/` prefix:

```lua
-- ✅ Correct
require("dst-controller/global")
require("dst-controller/utils/helpers")
require("dst-controller/actions/init")

-- ❌ Wrong
require("global")  -- Missing namespace
require("utils/helpers")  -- Missing namespace
```

### UI Development

When creating new screens/widgets:
- Use `require()` for DST widgets: `require("widgets/screen")`
- Use `G.Class()` instead of `Class()`
- Use `G.ANCHOR_*`, `G.SCALEMODE_*` constants
- Support both keyboard and gamepad input
- Implement `GetHelpText()` for dynamic help display

#### Widget Positioning and Anchors

**Widget Anchors** (`SetHAnchor` / `SetVAnchor`):

- Each widget has independent anchor settings (not inherited by children)
- Anchors determine which point of the widget is used as the position reference
- Horizontal: `ANCHOR_LEFT` (1), `ANCHOR_MIDDLE` (0), `ANCHOR_RIGHT` (2)
- Vertical: `ANCHOR_TOP` (1), `ANCHOR_MIDDLE` (0), `ANCHOR_BOTTOM` (2)
- Default is `ANCHOR_MIDDLE` for both horizontal and vertical

**ScrollableList Item Positioning**:

- ScrollableList always positions items at `-width/2 + x_offset`
- Items are positioned using their center point (if using default `ANCHOR_MIDDLE`)
- To center items within ScrollableList, use `widgetXOffset = width/2` parameter:

```lua
ScrollableList(
    items,
    600, 300, 70, 10,     -- width, height, itemheight, itempadding
    nil, nil, 600/2,       -- updatefn, widgetstoupdate, widgetXOffset (offset to center)
    nil, nil, nil, nil, nil,
    "GOLD"
)
```

**Two-Layer Container Pattern for ScrollableList**:

When items need centered layout within ScrollableList:

```lua
-- Create outer container (managed by ScrollableList)
local container = Widget("container")

-- Create inner content widget
local widget = container:AddChild(Widget("content"))

-- Add UI elements to widget
local button1 = widget:AddChild(...)
local button2 = widget:AddChild(...)

-- Use Layout.HorizontalRow with anchor="center" for centered layout
Layout.HorizontalRow({
    {widget = button1, width = 100},
    {widget = button2, width = 100},
}, {
    spacing = 10,
    start_x = 0,
    start_y = 0,
    anchor = "center"  -- Centers content from start_x
})

-- Set focus forwarding for gamepad navigation
container.focus_forward = button1

-- Return container to ScrollableList
return container
```

**Spinner Widget Styles**:

- `lean = true`: Transparent background, white text, separate arrow textures
- `lean = false` (default): Solid background, configurable text color
- Callback `onchangedfn(selected_data)` receives data value directly, not an object
- Use `GetSelectedData()` to get current selection (returns only the `data` field)

**Focus Management Best Practices**:

- Always set `focus_forward` on container widgets that don't directly handle input
- When using ScrollableList with empty state, hide the list and show separate empty text widget
- Empty widgets in ScrollableList cannot receive focus, causing focus loss issues
- After `RefreshActionsList` or similar operations, ensure focus is restored to appropriate widget
- Tab switching should delegate focus management to refresh methods, not force focus directly

### Configuration Changes

When modifying button combinations or actions:
- Update `config/tasks.lua` (default configuration)
- Configuration file format:
  ```lua
  {
      LB_A = {
          on_press = {
              {"action_name", "parameter"}  -- or just {"action_name"}
          },
          on_release = {}
      },
      -- ...
  }
  ```

## Common Patterns

### Hook Pattern

```lua
local G = require("dst-controller/global")

local MyHook = {}

function MyHook.Install()
    G.AddComponentPostInit("component_name", function(self)
        local old_Method = self.Method

        self.Method = function(self, ...)
            -- Your logic here

            -- Optionally call original
            return old_Method(self, ...)
        end
    end)
end

return MyHook
```

### Action Pattern

```lua
local G = require("dst-controller/global")

return {
    my_action = function(player, param)
        if not player or not player:IsValid() then
            return
        end

        -- Action implementation
        -- Use G.* for game objects
    end,
}
```

### Screen Pattern

```lua
local G = require("dst-controller/global")

local Screen = require("widgets/screen")
local Widget = require("widgets/widget")

local MyScreen = G.Class(Screen, function(self)
    Screen._ctor(self, "MyScreen")

    -- Setup UI
end)

function MyScreen:OnControl(control, down)
    if control == G.CONTROL_CANCEL and not down then
        G.TheFrontEnd:PopScreen()
        return true
    end
    return false
end

return MyScreen
```

## Testing

1. Load the mod in DST
2. Check console for initialization messages:
   ```
   [Enhanced Controller] Loaded saved configuration from file
   [TaskConfigHook] Task config hotkey installed
   [TaskConfigHook]   Keyboard: Ctrl+K
   [TaskConfigHook]   Gamepad: LB+RB+Y (同时按下)
   ```
3. Test button combinations in-game
4. Test config UI (Ctrl+K or LB+RB+Y)
5. Test config persistence (restart game)

## Known Limitations

- Client-only mod (doesn't affect server)
- Configuration UI requires pausing/menu access
- Some actions may not work in all game states
- Text input in config UI uses presets (no free text input)

## Common Issues and Solutions

### ScrollableList Items Not Centered

**Problem**: Items in ScrollableList appear shifted to the left, with half of the content outside the visible area.

**Root Cause**: ScrollableList positions items at `-width/2 + x_offset` by default, which places the item's center point at the left edge.

**Solution**: Set `widgetXOffset` parameter to `width/2` when creating ScrollableList:

```lua
ScrollableList(
    items,
    600, 300, 70, 10,
    nil, nil, 600/2,  -- widgetXOffset = width/2
    nil, nil, nil, nil, nil,
    "GOLD"
)
```

### Focus Loss When Switching Tabs with Empty Lists

**Problem**: When both tabs in ActionDetailScreen are empty, switching tabs with LT/RT causes focus to disappear.

**Root Cause**: Empty container widgets in ScrollableList cannot receive focus because they have no `focus_forward` set.

**Solution**: Use separate empty text widget instead of adding empty containers to ScrollableList:

```lua
-- Create empty text outside of ScrollableList
self.empty_text = self.root:AddChild(Text(...))
self.empty_text:SetPosition(0, 50)
self.empty_text:Hide()

-- In RefreshActionsList:
if #actions == 0 then
    self.empty_text:Show()
    self.scroll_list:Hide()
    self.add_action_button:SetFocus()
else
    self.empty_text:Hide()
    self.scroll_list:Show()
    -- Add items to scroll_list
end
```

### Spinner Callback Data Access Issues

**Problem**: Spinner `onchangedfn` callback fails when trying to access `selected.data`.

**Root Cause**: The callback receives the data value directly, not an object with a `data` field.

**Solution**: Use the parameter directly:

```lua
-- ❌ Wrong
spinner.onchangedfn = function(selected)
    local value = selected.data  -- Error: selected is not a table
end

-- ✅ Correct
spinner.onchangedfn = function(selected_data)
    local value = selected_data  -- selected_data is the actual value
end
```

## Version History

- **2.0.0**: Added in-game config UI, gamepad hotkey support, persistence system, refactored to namespace structure
- **1.0.0**: Initial release with basic button combinations and camera controls
