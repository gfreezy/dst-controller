# Enhanced Controller for Don't Starve Together

English | [简体中文](README.md)

A powerful controller enhancement mod for Don't Starve Together with custom button combinations, virtual cursor, map auto-pathfinding, in-game configuration UI, and more.

## ✨ Core Features

### 🌟 Feature Highlights

- 🎮 **12 Custom Button Combos** - Fully configurable gamepad button mapping
- 🖱️ **Virtual Cursor System** - Gamepad-controlled mouse cursor, full screen interaction
- 🗺️ **Map Auto-Pathfinding** - Click map to auto-navigate, intelligent path planning
- 🕳️ **Wormhole Tracking** - Auto-record wormhole pairs, show numbers on map
- ⚙️ **In-Game Configuration** - No restart needed, adjust all settings in real-time
- 🌍 **Multi-Language Support** - Chinese/English auto-detection
- 🎯 **Smart Target Selection** - Triple target system (main/alt/examine)
- 📐 **Enhanced Camera Control** - Smooth zoom and rotation

---

### 🎮 Custom Button Combinations

Supports **12 button combinations**, each configurable for press and release actions:

- **LB + A/B/X/Y/LT/RT**
- **RB + A/B/X/Y/LT/RT**

Each combination supports:

- Actions on press (`on_press`)
- Actions on release (`on_release`)
- Action sequences (multiple actions in a row)

### 🖱️ Virtual Cursor System

Use the right stick to control a mouse cursor for full mouse-mode operations:

**Features**:

- ✅ Right stick controls cursor movement (full screen)
- ✅ RT button = Left mouse click
- ✅ RB button = Right mouse click
- ✅ Hover detection and entity highlighting
- ✅ Drag-to-walk support (8-frame detection threshold)
- ✅ Click UI elements (inventory, crafting menu, etc.)
- ✅ Configurable cursor speed (0.5x - 2.0x)
- ✅ Configurable dead zone (0.0 - 0.5)
- ✅ Show/hide cursor icon

**Default toggle**: LB + RB + RT (press simultaneously)

### 🎯 Multi-Target Selection System

Intelligent target selection with three independent targets:

1. **Main Target** (`controller_target`) - A button interaction
   - Entities that support primary actions

2. **Alternative Target** (`controller_alternative_target`) - B button interaction
   - Entities with only secondary actions
   - Automatically cleared if main target has secondary action

3. **Examine Target** (`controller_examine_target`) - Y button examine
   - Entities that can only be examined (e.g., decorations)
   - Automatically cleared if main/alternative targets can be examined

**Target Selection Features**:

- Independent scoring system
- 360° or forward-only selection modes
- Distance and angle weight calculation
- Non-penetrable entities prioritized

### ⚙️ In-Game Configuration UI

Press **Ctrl+K** (keyboard) or **LB+RB+Y** (controller) to open the config UI:

**Features**:

- 🎨 3-layer interface: Main → Detail → Action Editor
- 🎮 Full controller support (A/B select/cancel, LB/RB tab switching)
- 💾 Real-time saving
- 🔄 Instant effect (no restart needed)
- 🎯 Two tabs:
  - **Button Config**: Configure 12 button combinations
  - **Mod Settings**: Adjust attack angle, interaction angle, force attack mode, virtual cursor settings

### 📐 Enhanced Camera Control

- **LB + Right Stick Left/Right**: Rotate camera
- **LB + Right Stick Up/Down**: Zoom camera
- Configurable rotation and zoom speeds

### 🗺️ Map Auto-Pathfinding

Use virtual cursor on the map screen to quickly navigate to target locations:

**Features**:
- ✅ Virtual cursor click on map to start auto-pathfinding
- ✅ Hybrid pathfinding system (A* algorithm for long distance + direct walk for short distance)
- ✅ Real-time path visualization (path points shown on map)
- ✅ Manual movement auto-cancels pathfinding
- ✅ Automatic obstacle avoidance

**How to Use**:
1. Press `M` key to open map
2. Press `LB+RB+RT` to enable virtual cursor mode
3. Use right stick to move cursor to target location
4. Press `RT` (left mouse click) to click on map
5. Close map, character will auto-pathfind to target location

**Map Controls**:
- **Left Stick**: Pan map
- **LB + Right Stick Vertical**: Zoom map
- **LB + Right Stick Horizontal**: Rotate camera
- **RT**: Click map to set pathfinding target
- **RB**: Right click (cancel/other actions)

### 🕳️ Wormhole Tracking System

Automatically record wormhole pair connections - no manual marking needed!

**Features**:
- ✅ Auto-record: Records entry/exit positions when using wormholes
- ✅ Pair identification: Automatically identifies which wormholes are connected
- ✅ Map display: Shows pair numbers on map (same number = connected pair)
- ✅ Persistent storage: Data saved locally, separate for each world
- ✅ Multiplayer support: Works in multiplayer servers

**How to Use**:
1. Use a wormhole normally (jump in)
2. System automatically records the connection between entry and exit wormholes
3. Open map - explored wormhole pairs will show matching numbers
4. Next time you see numbers on the map, you'll know which wormholes are connected!

**Storage Location**:
`client_save/wormhole_pairs_[world_id].json`

**Pathfinding Algorithm**:
- Uses Dijkstra algorithm with terrain cost awareness
- Automatic obstacle and impassable terrain avoidance
- Path points displayed in real-time on map

**Terrain Cost System**:
| Terrain | Speed Modifier | Path Cost |
|---------|---------------|-----------|
| Roads/Cobblestone | +30% | 0.77 (preferred) |
| Normal Ground | 0% | 1.0 |
| Rocky/Marsh | 0% | 1.2-1.5 |
| Sinkhole | -70% | 3.33 (avoided) |
| Spider Creep | -40% + attack risk | 5.0 (strongly avoided) |

## 🎬 Available Actions

### Combat

- **attack**: Attack target
- **force_attack**: Force attack (ignore friendly fire)

### Inspection

- **examine**: Examine target
- **inspect_self**: Examine yourself

### Equipment

- **equip_item**: Equip specified item
- **cycle_head**: Cycle head equipment
- **cycle_hand**: Cycle hand equipment
- **cycle_body**: Cycle body equipment

### Items

- **use_item_on_self**: Use item on self (D-pad Right)
- **use_item_on_scene**: Use item on scene/target (D-pad Left)
- **use_active_item_on_self**: Use cursor-selected item on self
- **use_active_item_on_scene**: Use cursor-selected item on scene
- **save_hand_item**: Save held item to cache
- **restore_hand_item**: Restore cached item to hand

### Crafting

- **craft_item**: Craft specified item

### System

- **trigger_key**: Trigger keyboard key
- **enable_virtual_cursor**: Enable virtual cursor
- **disable_virtual_cursor**: Disable virtual cursor

### ⏱️ Auto-Delay System

Equipment/item actions automatically wait **0.3 seconds** before the next action, ensuring state sync in multiplayer.

**Actions with auto-delay**:
- Equipment: `equip_item`, `unequip_item`, `cycle_*`, `swap_*_last`, `restore_*_item`
- Item usage: `use_item_on_self`, `use_item_on_scene`, `use_active_item_*`, `use_equip`

**Example config** (no manual delay needed):
```
on_press: save_hand_item → equip_item(lighter) → use_item_on_scene(lighter)
on_release: use_item_on_scene(lighter) → restore_hand_item
```
The system automatically adds 0.3s delay between `equip_item` and `use_item_on_scene`.

## 📦 Installation

### Method 1: Steam Workshop (Recommended)

1. Search "Enhanced Controller" on Steam Workshop
2. Click Subscribe
3. Launch game, auto-loads

### Method 2: Manual Installation

1. Download latest version
2. Extract to Mods directory:
   - **Windows**: `Documents/Klei/DoNotStarveTogether/mods/`
   - **Mac**: `~/Documents/Klei/DoNotStarveTogether/mods/`
   - **Linux**: `~/.klei/DoNotStarveTogether/mods/`
3. Launch game
4. Main menu → Mods → Enable "Enhanced Controller"

## 🎯 Quick Start

### 1. Open Configuration UI

- **Keyboard**: `Ctrl+K`
- **Controller**: `LB+RB+Y` (simultaneously)

### 2. Configure Button Combinations

1. Select a button combination (e.g., `LB_A`)
2. Select `On Press` or `On Release` tab
3. Click `+ Add Action`
4. Select action type and parameter
5. Click `Apply` to save

### 3. Use Virtual Cursor

1. Press `LB+RB+RT` to enable virtual cursor mode
2. Use right stick to move cursor
3. `RT` = Left click, `RB` = Right click
4. Press `LB+RB+RT` again to exit

## ⚙️ Configuration Options

### Attack Angle Mode

- **Forward Only**: Attack enemies in front only
- **All Around**: Attack enemies in all directions

### Interaction Angle Mode

- **Forward Only**: Interact with items in front only
- **All Around**: Interact with items in all directions

### Force Attack Mode

- **Hostile Only**: Only attack hostile creatures
- **All Creatures**: Attack all creatures (including allies)

### Virtual Cursor Settings

- **Cursor Speed**: 0.5x - 2.0x (default 1.0x)
- **Dead Zone**: 0.0 - 0.5 (default 0.1)
- **Show Cursor**: On/Off

## 🛠️ Configuration File

Configuration saved to: `client_save/enhanced_controller_config.json`

**Structure**:

```json
{
  "tasks": {
    "LB_A": {
      "on_press": [["attack"], ["examine"]],
      "on_release": []
    },
    ...
  },
  "settings": {
    "attack_angle_mode": "forward_only",
    "interaction_angle_mode": "all_around",
    "force_attack_mode": "hostile_only",
    "virtual_cursor_settings": {
      "enabled": true,
      "toggle_combo": ["LB", "RB", "RT"],
      "left_click_key": "RT",
      "right_click_key": "RB",
      "cursor_speed": 1.0,
      "dead_zone": 0.1,
      "show_cursor": true
    }
  }
}
```

## 🎮 Button Mapping Reference

| Xbox Button | PS Button | Function |
|------------|-----------|----------|
| LB | L1 | Left Bumper (combo modifier) |
| RB | R1 | Right Bumper (combo modifier) |
| LT | L2 | Left Trigger |
| RT | R2 | Right Trigger |
| A | ❌ | Confirm/Interact |
| B | ⭕ | Cancel/Alt Action |
| X | ⬜ | Primary Action |
| Y | 🔺 | Examine |
| Right Stick | R3 | Virtual Cursor/Camera Control |

## 📋 Notes

1. **Client-side Mod**: Only you need to install, doesn't affect other players
2. **Compatibility**: Compatible with most other mods
3. **Config Sync**: Same config used for all characters
4. **Pause Feature**: Config UI pauses game (singleplayer/host)

## 🔧 Development Info

- **Version**: 2.3.0
- **Author**: feichao
- **API Version**: 10
- **Compatibility**: Don't Starve Together

### Project Structure

```
dst-controller/
├── modinfo.lua                 # Mod metadata
├── modmain.lua                 # Entry point
├── scripts/dst-controller/
│   ├── global.lua             # Global references
│   ├── localization.lua       # Multi-language support
│   ├── actions/               # Action implementations
│   ├── core/                  # Core logic
│   │   ├── button-handler.lua
│   │   └── action-executor.lua
│   ├── hooks/                 # Game hooks
│   │   ├── registry.lua       # Hook registry
│   │   ├── playercontroller-hook.lua
│   │   ├── mapscreen-hook.lua # Map screen hooks
│   │   ├── input-system-hook.lua
│   │   └── controls-hook.lua
│   ├── screens/               # UI screens
│   │   └── taskconfig-screen.lua
│   ├── virtual-cursor/        # Virtual cursor
│   │   ├── core.lua
│   │   └── cursor_widget.lua
│   ├── target-selection/      # Target selection
│   │   └── core.lua
│   ├── pathfinding/           # Pathfinding system (deprecated)
│   │   └── ...                # Legacy A* implementation
│   └── utils/                 # Utility functions
│       ├── client_pathfinder.lua # Dijkstra pathfinding with terrain costs
│       ├── map_path_drawer.lua # Path drawing
│       └── helpers.lua
└── CLAUDE.md                  # Development docs
```

## 🐛 FAQ

**Q: Can't select inventory slots in virtual cursor mode?**

A: Virtual cursor mode automatically clears inventory selection. Click slots directly with the cursor.

**Q: Config UI won't open?**

A: Make sure you're not in another menu. Press `Ctrl+K` or `LB+RB+Y`.

**Q: Button combinations not responding?**

A: Check config UI has actions set correctly. Ensure all buttons pressed simultaneously.

**Q: How to restore default config?**

A: Delete `client_save/enhanced_controller_config.json` and restart game.

**Q: Game stuttering?**

A: Try lowering virtual cursor speed or disabling cursor display.

**Q: Auto-pathfinding not working?**

A: Make sure you enable virtual cursor on the map screen and click on a valid ground location. Pathfinding will fail if the path is completely blocked by obstacles.

**Q: Pathfinding stops midway?**

A: Any manual movement (stick input) will automatically cancel pathfinding. This is by design to prevent conflicts.

**Q: Can't see path on map?**

A: Path visualization only shows when the map is open. After closing the map, the character will follow the planned path, but path points won't be visible.

## 📝 Changelog

### v2.3.0
- ✨ Added Wormhole Tracking System
  - Auto-record wormhole pair connections
  - Display pair numbers on map
  - Persistent storage (separate for each world)
- ✨ Added auto-delay system between actions (0.3s), ensuring multiplayer state sync
- ✨ `FindItemByName` now also searches equipped slots (HANDS/HEAD/BODY)
- 🔧 Removed `start_channeling` and `stop_channeling` actions
  - Use `equip_item` + `use_item_on_scene` combo instead
  - System handles delay automatically
- 🔧 Improved item action multiplayer compatibility

### v2.2.1
- 🔧 Improved spider creep detection using native `GroundCreep:OnCreep()` API
- 🔧 Updated terrain costs based on official DST speed modifiers

### v2.2.0
- ✨ Switched pathfinding to Dijkstra algorithm with terrain cost awareness
- ✨ Added terrain-based path optimization:
  - Roads prioritized (+30% speed bonus)
  - Spider creep avoided (-40% speed + attack risk)
  - Sinkholes avoided (-70% speed penalty)
  - Marsh, rocky, meteor zones considered
- ✨ Added cave support for pathfinding
- 🔧 Fixed player movement using `RemoteDirectWalking`/`RemoteStopWalking`
- 🔧 Added pause detection for stuck checking

### v2.1.0
- ✨ Added map auto-pathfinding feature
  - Virtual cursor click on map to start pathfinding
  - Hybrid pathfinding algorithm (A* + direct walk)
  - Real-time path visualization
  - Manual movement auto-cancels
- ✨ Added multi-language support (Chinese/English)
  - Auto-detect game language
  - Full UI localization
- 🔧 Optimized map screen controls
  - LB + Right Stick Vertical for zoom
  - LB + Right Stick Horizontal for rotation
  - Left Stick for map panning
- 🐛 Fixed multiple issues with virtual cursor mode

### v2.0.0

- ✨ Added in-game configuration UI
- ✨ Added virtual cursor system
- ✨ Added multi-target selection (main/alt/examine)
- ✨ Refactored to namespace architecture
- 🔧 Optimized hook system (centralized registry)
- 💾 Added config persistence
- 🎮 Enhanced controller support

### v1.0.0 (Initial Release)

- Basic button combination features
- Enhanced camera control

## 📜 License

MIT License - See [LICENSE](LICENSE) file

## 🤝 Contributing

Issues and Pull Requests welcome!

### Development Guide

See [CLAUDE.md](CLAUDE.md) for project architecture and development guidelines.

## 🔗 Links

- **Steam Workshop**: [Coming soon]
- **GitHub**: [Repository URL]
- **Issue Tracker**: [Issues page]

## ❤️ Thanks

Thanks to all contributors and players using this mod!

---

**Enjoy the enhanced controller experience!** 🎮✨
