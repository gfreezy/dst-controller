# Enhanced Controller for Don't Starve Together

English | [简体中文](README.md)

A powerful controller enhancement mod for Don't Starve Together with custom button combinations, virtual cursor, in-game configuration UI, and more.

## ✨ Core Features

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

- **use_item**: Use item on target
- **use_item_on_self**: Use item on self
- **save_hand_item**: Save held item to cache
- **restore_hand_item**: Restore cached item to hand

### Crafting

- **craft_item**: Craft specified item

### Character

- **start_channeling**: Start channeling (Wanda)
- **stop_channeling**: Stop channeling

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

- **Version**: 2.0.0
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
│   ├── actions/               # Action implementations
│   ├── core/                  # Core logic
│   │   ├── button-handler.lua
│   │   └── action-executor.lua
│   ├── hooks/                 # Game hooks
│   │   ├── registry.lua       # Hook registry
│   │   ├── playercontroller-hook.lua
│   │   ├── input-system-hook.lua
│   │   └── controls-hook.lua
│   ├── screens/               # UI screens
│   │   ├── taskconfig-screen.lua
│   │   └── taskconfig-actions.lua
│   ├── virtual-cursor/        # Virtual cursor
│   │   ├── core.lua
│   │   └── cursor_widget.lua
│   ├── target-selection/      # Target selection
│   │   └── core.lua
│   └── utils/                 # Utility functions
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

## 📝 Changelog

### v2.0.0 (2025-01-XX)

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
