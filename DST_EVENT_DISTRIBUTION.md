# DST Event Distribution System

This document provides a comprehensive analysis of Don't Starve Together's event distribution and input handling system.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Event Flow](#event-flow)
3. [Return Value Semantics](#return-value-semantics)
4. [Dual Input Architecture](#dual-input-architecture)
5. [Joystick Dual Nature](#joystick-dual-nature)
6. [Input System Independence](#input-system-independence)
7. [Focus System](#focus-system)
8. [PlayerHud Layer](#playerhud-layer)
9. [PlayerController States](#playercontroller-states)
10. [Common Patterns](#common-patterns)
11. [Best Practices](#best-practices)

---

## Architecture Overview

DST's input system consists of two independent paths:

```
┌─────────────────────────────────────────────────────────────┐
│                      C++ Engine (TheSim)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐      ┌────────────────────────┐   │
│  │ Hardware State Cache│      │   OnControl Events     │   │
│  │   (Direct Read)     │      │   (Notifications)      │   │
│  └─────────────────────┘      └────────────────────────┘   │
│           │                              │                   │
└───────────┼──────────────────────────────┼───────────────────┘
            │                              │
            ↓                              ↓
    ┌───────────────┐            ┌─────────────────┐
    │ Polling Path  │            │   Event Path    │
    └───────────────┘            └─────────────────┘
            │                              │
            ↓                              ↓
    IsControlPressed()           Input:OnControl()
    GetAnalogControlValue()              ↓
            │                    TheFrontEnd:OnControl()
            ↓                              ↓
    OnUpdate loops               Screen:OnControl()
    (PlayerController,                   ↓
     FrontEnd,                   Widget:OnControl()
     Inventorybar, etc.)                 ↓
                                PlayerController:OnControl()
```

**Key Insight**: These two paths are **completely independent**:
- **Polling Path**: Direct C++ state queries, cannot be blocked by Lua code
- **Event Path**: Lua-level notifications, can be intercepted and blocked

---

## Event Flow

### OnControl Event Distribution

```lua
C++ Engine
  ↓
Input:OnControl(control, digitalvalue, analogvalue)
  │
  ├─ Check mouse_enabled or control type
  ├─ Call TheFrontEnd:OnControl(control, digitalvalue) ← Returns true/false
  │   │
  │   └─ If returns true: STOP (event consumed by UI)
  │
  └─ If FrontEnd returns false/nil:
      ├─ self.oncontrol:HandleEvent(control, digitalvalue, analogvalue)
      └─ self.oncontrol:HandleEvent("oncontrol", control, digitalvalue, analogvalue)
          │
          └─ Notify all listeners (return values IGNORED)
              ├─ PlayerController:OnControl
              ├─ Other registered listeners
              └─ ...
```

**Code Reference**: [scripts-raw/input.lua](scripts-raw/input.lua:OnControl)

```lua
function Input:OnControl(control, digitalvalue, analogvalue)
    if (self.mouse_enabled or
        (control ~= CONTROL_PRIMARY and control ~= CONTROL_SECONDARY)) and
        not TheFrontEnd:OnControl(control, digitalvalue) then
        self.oncontrol:HandleEvent(control, digitalvalue, analogvalue)
        self.oncontrol:HandleEvent("oncontrol", control, digitalvalue, analogvalue)
    end
end
```

### TheFrontEnd:OnControl

```lua
TheFrontEnd:OnControl(control, down)
  │
  ├─ IsControlsDisabled() → return false (don't block)
  │
  ├─ Get top screen from screenstack
  │
  └─ Call screen:OnControl(control, down)
      │
      └─ Screen:OnControl (from Widget class)
          │
          ├─ Check if self has focus
          │
          ├─ Try children widgets (recursive)
          │   └─ for k,v in pairs(self.children) do
          │       if v.focus and v:OnControl(control, down) then
          │           return true  -- Child handled it
          │       end
          │
          └─ Handle at current level or return false
```

**Code Reference**: [scripts-raw/frontend.lua](scripts-raw/frontend.lua:OnControl)

```lua
function FrontEnd:OnControl(control, down)
    self.isprimary = control == CONTROL_PRIMARY
    if self:IsControlsDisabled() then
        self.isprimary = false
        return false
    elseif #self.screenstack > 0
        and self.screenstack[#self.screenstack]:OnControl(control, down)
    then
        self.isprimary = false
        return true  -- Event consumed by UI
    end
    self.isprimary = false
end
```

### IsControlsDisabled - Global Control Lock

**Purpose**: Globally disable all input during "unstable states" (scene transitions, errors).

**Code Reference**: [scripts-raw/frontend.lua](scripts-raw/frontend.lua:390)

```lua
function FrontEnd:IsControlsDisabled()
    return self:GetFadeLevel() > 0
        or (self.fadedir == FADE_OUT and self.fade_delay_time == nil)
        or global_error_widget ~= nil
end

function FrontEnd:GetFadeLevel()
    return self.alpha  -- 0 = fully visible, 1 = fully black
end
```

#### Returns `true` in three scenarios

| Condition | When | Purpose |
|-----------|------|---------|
| `GetFadeLevel() > 0` | Screen fading in/out | Prevent input during scene transitions |
| `fadedir == FADE_OUT && fade_delay_time == nil` | Fade-out delay finished | Lock input when fade actually starts |
| `global_error_widget ~= nil` | Script error screen shown | Disable game input, only show error |

**Example: Scene Transition**

```lua
-- When switching scenes
TheFrontEnd:Fade(FADE_OUT, 1.0, function()
    -- Callback after fade completes
    LoadNewScene()
end)

-- During fade (0-1 seconds):
-- - GetFadeLevel() gradually increases from 0 to 1
-- - IsControlsDisabled() returns true
-- - All OnControl events are blocked
-- - OnFocusMove also blocked (combined with focus_locked check)
```

**Effect in Event Chain**:

```
User presses button
  ↓
Input:OnControl
  ↓
TheFrontEnd:OnControl
  ├─ IsControlsDisabled() returns true
  └─ return false (but already blocked internally)
      ╳
  (Event still propagates to EventProcessor!)
      ↓
  PlayerController:OnControl still receives event
```

**Important**: `IsControlsDisabled()` only blocks at FrontEnd/UI level. EventProcessor listeners (like PlayerController) still receive events! However, UI won't process input, which is usually sufficient.

**Similar Check in OnFocusMove**:

```lua
function FrontEnd:OnFocusMove(dir, down)
    if self.focus_locked or self:IsControlsDisabled() then
        return true  -- Block focus movement
    end
    -- ... normal focus movement
end
```

**Use Cases**:
- **Screen transitions**: Player shouldn't interact during fade in/out
- **Loading screens**: Block input while assets load
- **Error states**: Only allow viewing error message, no game input
- **Cutscenes**: Some mods may use fade system for cutscenes

---

## Return Value Semantics

### In TheFrontEnd:OnControl

- **`true`**: Event consumed by UI, **stops propagation to EventProcessor listeners**
- **`false` or `nil`**: Event not handled by UI, continues to EventProcessor

### In Widget:OnControl / Screen:OnControl

- **`true`**: Widget handled the event, **stops checking siblings and propagates true to parent**
- **`false` or `nil`**: Widget didn't handle, **continues checking next sibling**

**Important**: Widget return values only affect widget tree traversal, not EventProcessor listeners!

### In EventProcessor Listeners (e.g., PlayerController:OnControl)

- **Return values are IGNORED**
- All registered listeners receive the event
- Cannot block each other

**Code Reference**: [scripts-raw/events.lua](scripts-raw/events.lua:HandleEvent)

```lua
function EventProcessor:HandleEvent(event, ...)
    local handlers = self.events[event]
    if handlers then
        for k,v in pairs(handlers) do
            k.fn(...)  -- Call all handlers, no return value check
        end
    end
end
```

### Flow Diagram

```
Input:OnControl
  ↓
TheFrontEnd:OnControl
  ├─ returns true → STOP (no EventProcessor notification)
  └─ returns false/nil → Continue
      ↓
      EventProcessor:HandleEvent
      ├─ PlayerController:OnControl ← Return ignored
      ├─ Other Listener 1 ← Return ignored
      ├─ Other Listener 2 ← Return ignored
      └─ ...
```

### Example: Blocking RT Button in HUD Hook

```lua
-- ❌ WRONG: return false doesn't block
function PlayerHud:OnControl(control, down)
    if PlayerHud._base.OnControl(self, control, down) then
        return true
    end

    if control == CONTROL_OPEN_INVENTORY then
        if ModifierKeyPressed() then
            return false  -- ❌ Doesn't block! Event continues to PlayerController
        end
    end

    -- ... handle normally
end

-- ✅ CORRECT: return true blocks
function PlayerHud:OnControl(control, down)
    if PlayerHud._base.OnControl(self, control, down) then
        return true
    end

    if control == CONTROL_OPEN_INVENTORY then
        if ModifierKeyPressed() then
            return true  -- ✅ Blocks event from propagating
        end
    end

    -- ... handle normally
end
```

---

## Dual Input Architecture

DST uses two different systems for handling input:

### 1. Event-Driven (OnControl)

**Used for**: Discrete button press/release actions
- A, B, X, Y buttons
- LT, RT, LB, RB buttons (digital aspect)
- D-Pad
- Mouse clicks

**Flow**:
```
Button pressed → C++ generates event → Input:OnControl → TheFrontEnd:OnControl → ...
```

**Characteristics**:
- Single notification per state change (press/release)
- Can be intercepted at UI layer (TheFrontEnd:OnControl return true)
- Listeners registered via EventProcessor receive event (if not blocked by UI)

### 2. Polling-Driven (OnUpdate)

**Used for**: Continuous analog input and state queries
- Left stick (movement)
- Right stick (camera)
- Button state queries

**Flow**:
```
OnUpdate loop → IsControlPressed() → TheSim:GetDigitalControl() → C++ hardware cache
OnUpdate loop → GetAnalogControlValue() → TheSim:GetAnalogControl() → C++ hardware cache
```

**Characteristics**:
- Continuous polling every frame
- **Cannot be blocked** by OnControl event handlers
- Bypasses Lua event system entirely

**Code Reference**: [scripts-raw/input.lua](scripts-raw/input.lua)

```lua
function Input:IsControlPressed(control)
    control = self:ResolveVirtualControls(control)
    return control ~= nil and TheSim:GetDigitalControl(control)  -- Direct C++ read
end

function Input:GetAnalogControlValue(control)
    control = self:ResolveVirtualControls(control)
    return control and TheSim:GetAnalogControl(control) or 0  -- Direct C++ read
end
```

### Example: Left Stick in HUD Blocking Mode

**Problem**: How can left stick control both character movement AND UI navigation simultaneously?

**Answer**: They use different detection methods!

```lua
-- Character Movement (PlayerController:OnUpdate)
function PlayerController:DoPredictWalking(dt)
    -- Uses analog values (continuous)
    local x = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) -
              TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
    local y = TheInput:GetAnalogControlValue(CONTROL_MOVE_UP) -
              TheInput:GetAnalogControlValue(CONTROL_MOVE_DOWN)
    -- Process movement...
end

-- UI Navigation (FrontEnd:OnUpdate)
function FrontEnd:OnUpdate(dt)
    -- Uses digital values (threshold-based)
    if TheInput:IsControlPressed(CONTROL_MOVE_LEFT) or
       TheInput:IsControlPressed(CONTROL_FOCUS_LEFT) then
        self:OnFocusMove(MOVE_LEFT, true)
    end
    -- ...
end
```

**Result**: Both systems read from C++ hardware cache independently → both work simultaneously!

---

## Joystick Dual Nature

Joysticks generate **both** digital and analog values:

### Analog Value
- **Range**: -1.0 to +1.0 (continuous)
- **Used for**: Character movement, camera control
- **Read via**: `GetAnalogControlValue()`
- **Processed in**: `OnUpdate` loops

### Digital Value
- **Range**: 0 or 1 (discrete)
- **Threshold**: Generated when stick exceeds dead zone (~0.3)
- **Generates**: `OnControl` event
- **Used for**: Direction detection, UI navigation

### Why Joysticks "Can't Be Blocked"

```lua
function PlayerController:OnControl(control, down)
    if control == CONTROL_MOVE_UP then
        -- Even if you return here, movement still works!
        return true  -- ❌ This does NOT stop movement
    end
end
```

**Reason**: PlayerController doesn't use the OnControl event for movement! It uses polling:

```lua
function PlayerController:OnUpdate(dt)
    -- This runs every frame, regardless of OnControl events
    self:DoPredictWalking(dt)
        ↓
    GetAnalogControlValue(CONTROL_MOVE_UP)  -- Direct C++ read
end
```

**To actually block movement**, you must:
1. Call `PlayerController:Enable(false)`, OR
2. Hook `GetAnalogControlValue()` to return 0, OR
3. Stop the locomotor directly

---

## Input System Independence

**Critical Understanding**: OnControl events and state queries are **completely independent**.

### Test Case

```lua
-- Hook PlayerHud:OnControl
function PlayerHud:OnControl(control, down)
    if control == CONTROL_OPEN_INVENTORY then
        print("OnControl: RT pressed")
        return true  -- Block event
    end
    return OldOnControl(self, control, down)
end

-- Check in FrontEnd:OnUpdate
function FrontEnd:OnUpdate(dt)
    if TheInput:IsControlPressed(CONTROL_OPEN_INVENTORY) then
        print("IsControlPressed: RT is pressed")  -- ✅ Still prints!
    end
end
```

**Result**: Both print! Why?

```
RT Button Pressed
  │
  ├─→ C++ Hardware State Cache
  │    └─ IsControlPressed() ✅ returns true
  │
  └─→ OnControl Event
       └─ PlayerHud:OnControl returns true
           └─ Event blocked ✅ doesn't reach PlayerController
```

### Architecture Diagram

```
┌──────────────────────────────────────────────┐
│          C++ Engine (TheSim)                 │
│                                              │
│  Hardware State Cache (Direct Access)       │
│  ┌────────────────────────────────┐         │
│  │ RT: pressed = true             │         │
│  │ LT: pressed = false            │         │
│  │ Left Stick: x=0.5, y=0.0       │         │
│  └────────────────────────────────┘         │
│         ↑                    ↑               │
│         │                    │               │
└─────────┼────────────────────┼───────────────┘
          │                    │
          │                    │
    ┌─────┴─────┐       ┌──────┴──────┐
    │  Polling  │       │   Events    │
    └───────────┘       └─────────────┘
          │                    │
          ↓                    ↓
GetDigitalControl()    Input:OnControl()
GetAnalogControl()            ↓
          ↓            TheFrontEnd:OnControl()
          │                    ↓
          │            return true ← Blocks
          │                    ╳
          │                (stopped)
          ↓
    ✅ Always works    ❌ Can be blocked
```

### Practical Implications

1. **Blocking button actions**: Hook TheFrontEnd:OnControl or Widget:OnControl and return true
2. **Blocking movement**: Must hook polling path or disable PlayerController
3. **State queries always work**: IsControlPressed bypasses event system
4. **OnUpdate loops unaffected**: Polling continues regardless of event blocking

---

## Focus System

### Focus Tree Concept

Focus is a **tree-level concept**: both parent and child must have focus.

```
Screen (focus = true)
  └─ Widget A (focus = true)
      ├─ Button 1 (focus = true) ← Currently focused
      └─ Button 2 (focus = false)
```

**Code Reference**: [scripts-raw/widgets/widget.lua](scripts-raw/widgets/widget.lua)

```lua
function Widget:SetFocus()
    -- Focus forwarding
    local focus_forward = FunctionOrValue(self.focus_forward)
    if focus_forward then
        focus_forward:SetFocus()
        return
    end

    if not self.focus then
        self.focus = true
        if self.OnGainFocus then
            self:OnGainFocus()
        end

        if self.parent then
            self.parent:SetFocusFromChild(self)  -- Propagate upward
        end
    end

    -- Clear children focus
    for k,v in pairs(self.children) do
        v:ClearFocus()
    end
end
```

### LockFocus Effect

```lua
TheFrontEnd:LockFocus(true)   -- Lock focus movement
TheFrontEnd:LockFocus(false)  -- Unlock focus movement
```

**When locked**:
- OnFocusMove returns immediately without processing
- **Blocks ALL focus movement** (including between children)
- Focus cannot escape from current widget

**Code Reference**: [scripts-raw/frontend.lua](scripts-raw/frontend.lua:OnFocusMove)

```lua
function FrontEnd:OnFocusMove(dir, down)
    if self.focus_locked or self:IsControlsDisabled() then
        return true  -- Block focus movement but consume event
    end
    -- ... normal focus movement
end
```

**Common pattern**:
```lua
-- Opening inventory
self:SetFocus()
TheFrontEnd:LockFocus(true)  -- Lock focus to inventory

-- Closing inventory
TheFrontEnd:LockFocus(false)  -- Unlock focus
self:ClearFocus()
```

### Focus vs Active Slot (Inventorybar)

**Important**: Inventorybar does NOT use Widget focus system!

| Feature | Widget Focus | Inventorybar Active Slot |
|---------|-------------|--------------------------|
| **Concept** | Tree-level focus | Custom cursor |
| **Navigation** | OnFocusMove events | OnUpdate polling |
| **Input** | CONTROL_FOCUS_* | VIRTUAL_CONTROL_INV_* |
| **State** | widget.focus (boolean) | self.active_slot (reference) |
| **Affected by LockFocus** | Yes | No |

**Code Reference**: [scripts-raw/widgets/inventorybar.lua](scripts-raw/widgets/inventorybar.lua)

```lua
function Inv:OnUpdate(dt)
    -- Custom cursor navigation using virtual controls
    if TheInput:IsControlPressed(VIRTUAL_CONTROL_INV_LEFT) then
        self:RefreshRepeatDelay(VIRTUAL_CONTROL_INV_LEFT)
        self:CursorLeft()
        return
    elseif TheInput:IsControlPressed(VIRTUAL_CONTROL_INV_RIGHT) then
        self:RefreshRepeatDelay(VIRTUAL_CONTROL_INV_RIGHT)
        self:CursorRight()
        return
    end
    -- ...
end

function Inv:SelectSlot(slot)
    if slot and slot ~= self.active_slot then
        if self.active_slot and self.active_slot ~= slot then
            self.active_slot:DeHighlight()
        end

        self.active_slot = slot  -- Custom cursor, not focus!
        return true
    end
end
```

### OnFocusMove Mechanism

```lua
function Widget:OnFocusMove(dir, down)
    if not self.focus then return false end

    -- Try children first
    for k,v in pairs(self.children) do
        if v.focus and v:OnFocusMove(dir, down) then
            return true
        end
    end

    -- Try own focus_flow
    if down and self.focus_flow[dir] then
        local dest = FunctionOrValue(self.focus_flow[dir], self)
        if dest and dest:IsVisible() and dest.enabled then
            dest:SetFocus()
            return true
        end
    end

    return false
end
```

**Two branches**:
1. **Focused child handling**: Recurse into focused child first
2. **Focus flow**: Move to adjacent widget defined in focus_flow table

**Auto-adaptation** (FrontEnd:OnFocusMove):
```lua
function FrontEnd:OnFocusMove(dir, down)
    if self.screenstack[#self.screenstack]:OnFocusMove(dir, down) then
        self:GetSound():PlaySound("dontstarve/HUD/click_mouseover_controller")
        self.tracking_mouse = false  -- Switch from mouse to gamepad
        return true
    elseif self.tracking_mouse and down and
           self.screenstack[#self.screenstack]:SetDefaultFocus() then
        self.tracking_mouse = false  -- First gamepad input after mouse usage
        return true
    end
end
```

**Purpose of tracking_mouse**: Automatic input device switching
- Mouse used → tracking_mouse = true
- Gamepad d-pad pressed → SetDefaultFocus + tracking_mouse = false
- Seamless transition between mouse and gamepad

---

## PlayerHud Layer

### Overview

`PlayerHud` is a special screen that sits in FrontEnd's screen stack and acts as the **game UI layer** (inventory, crafting menu, health/hunger bars, etc.). It's the bridge between Widget-based UI and PlayerController-based gameplay.

**Code Reference**: [scripts-raw/screens/playerhud.lua](scripts-raw/screens/playerhud.lua:1328)

### PlayerHud:OnControl Structure

```lua
function PlayerHud:OnControl(control, down)
    -- 1. Try base class (Widget hierarchy)
    if PlayerHud._base.OnControl(self, control, down) then
        return true  -- Child widget handled it

    -- 2. Check if HUD is shown
    elseif not self.shown then
        -- Special case: server pause toggle when HUD hidden
        if self.serverpaused and down and control == CONTROL_SERVER_PAUSE then
            SetServerPaused(false)
            return true
        end
        return  -- HUD not shown, ignore all other controls

    -- 3. Check if control should be ignored
    elseif self.owner.components.playercontroller:ShouldPlayerHUDControlBeIgnored(control, down) then
        return true  -- Block this control
    end

    -- 4. Handle HUD-specific controls
    if down then
        if control == CONTROL_INSPECT then
            -- Inspect logic...
            return true
        elseif control == CONTROL_INSPECT_SELF then
            -- Self-inspect logic...
            return true
        end
    elseif control == CONTROL_PAUSE then
        -- Pause menu logic (different for gamepad vs keyboard)...
        return true
    elseif control == CONTROL_OPEN_CRAFTING then  -- LT button
        if self:IsCraftingOpen() then
            self:CloseCrafting()
        else
            self:OpenCrafting()
        end
        return true
    elseif control == CONTROL_OPEN_INVENTORY then  -- RT button
        if self:IsControllerInventoryOpen() then
            self:CloseControllerInventory()
        else
            self:OpenControllerInventory()
        end
        return true
    elseif control >= CONTROL_INV_1 and control <= CONTROL_INV_10 then
        -- Keyboard hotkeys 1-0 for inventory slots
        -- ...
        return true
    end

    -- 5. If nothing handled, return nil (allow propagation)
end
```

### Key Controls Handled by PlayerHud

| Control | Button | Action | When |
|---------|--------|--------|------|
| `CONTROL_OPEN_INVENTORY` | RT | Toggle inventory | Always (if has inventory) |
| `CONTROL_OPEN_CRAFTING` | LT | Toggle crafting menu | Always (if crafting enabled) |
| `CONTROL_PAUSE` | Start | Open pause menu | Always |
| `CONTROL_CANCEL` | B | Close UI (gamepad only) | When UI is open |
| `CONTROL_MAP` | Tab/Back | Toggle map | Always |
| `CONTROL_INSPECT` | Y | Inspect target or self | When no UI open |
| `CONTROL_INSPECT_SELF` | Alt | Inspect self | Always |
| `CONTROL_INV_1` ~ `CONTROL_INV_10` | 1-0 | Use inventory slot | Keyboard only |
| `CONTROL_OPEN_COMMAND_WHEEL` | LB+Y | Open command wheel | Always |
| `CONTROL_SHOW_PLAYER_STATUS` | Tab (hold) | Show player status | Always |

### RT/LT Button Handling Details

**RT Button (CONTROL_OPEN_INVENTORY)**:

```lua
elseif control == CONTROL_OPEN_INVENTORY then
    if self:IsControllerInventoryOpen() then
        self:CloseControllerInventory()
        return true
    end
    local inventory = self.owner.replica.inventory
    if inventory ~= nil and inventory:IsVisible() and inventory:GetNumSlots() > 0 then
        self:OpenControllerInventory()
        return true
    end
```

**LT Button (CONTROL_OPEN_CRAFTING)**:

```lua
elseif control == CONTROL_OPEN_CRAFTING then
    if self:IsCraftingOpen() then
        if TheInput:IsControlPressed(CONTROL_CRAFTING_MODIFIER) then
            self.controls.craftingmenu.craftingmenu:StartSearching(true)
        else
            self:CloseCrafting()
        end
        return true
    elseif not GetGameModeProperty("no_crafting") then
        local inventory = self.owner.replica.inventory
        if inventory ~= nil and inventory:IsVisible() then
            self:OpenCrafting(TheInput:IsControlPressed(CONTROL_CRAFTING_MODIFIER))
            return true
        end
    end
```

**Key Points**:
- Both controls are handled in `PlayerHud:OnControl`, **before** reaching `PlayerController:OnControl`
- Return `true` to consume event and prevent propagation
- To block RT/LT in mod: hook `PlayerHud:OnControl` and return `true` when modifier keys pressed

### Pause Menu Behavior (CONTROL_PAUSE)

**Gamepad Mode**:
```lua
if TheInput:ControllerAttached() then
    self.owner.components.playercontroller:CancelAOETargeting()
    self:CloseCrafting()
    self:CloseSpellWheel()
    if self:IsControllerInventoryOpen() then
        self:CloseControllerInventory()
    end
    TheFrontEnd:PushScreen(PauseScreen())  -- Always open pause menu
end
```

**Keyboard/Mouse Mode**:
```lua
else
    local closed = false
    -- Try closing open UIs first
    if self.owner.components.playercontroller:IsAOETargeting() then
        self.owner.components.playercontroller:CancelAOETargeting()
        closed = true
    end
    if self:IsCraftingOpen() then
        self:CloseCrafting()
        closed = true
    end
    -- ... close other UIs ...

    if not closed then
        TheFrontEnd:PushScreen(PauseScreen())  -- Only open if nothing closed
    end
end
```

**Design Difference**:
- **Gamepad**: Always open pause menu (close all UIs first)
- **Keyboard**: Esc key first closes open UIs, then opens pause menu
- **Reason**: Gamepad has dedicated back button (B), keyboard uses Esc for both

### HasInputFocus (Triggers HUD Blocking Mode)

```lua
function PlayerHud:HasInputFocus()
    local active_screen = TheFrontEnd:GetActiveScreen()
    return (active_screen ~= nil and active_screen ~= self)
        or TheFrontEnd.textProcessorWidget ~= nil
        or (self.controls ~= nil and (
            self.controls.inv.open or
            ((self:IsCraftingOpen() or
              self:IsSpellWheelOpen() or
              self:IsCommandWheelOpen()) and
             TheInput:ControllerAttached())
        ))
        or self.modfocus ~= nil
end
```

**Returns `true` when**:
1. **Another screen on top**: Pause menu, map, etc. (not PlayerHud itself)
2. **Text input active**: Chat, console, text edit widget
3. **Inventory open**: `self.controls.inv.open == true`
4. **Crafting/Spell/Command wheel open** (gamepad only): Only triggers HUD blocking in gamepad mode
5. **Mod sets focus**: `self.modfocus ~= nil` (for mod UIs)

**Effect**: When `HasInputFocus()` returns `true`, `PlayerController:IsEnabled()` returns `(false, true)` → **HUD blocking mode**

**Why gamepad-only for crafting/wheels?**
- **Keyboard/mouse**: Can click anywhere, no need to block player actions
- **Gamepad**: Uses d-pad/stick for navigation, needs to block interaction controls to prevent conflicts

### Event Flow Example: Blocking RT When LB Pressed

**Goal**: In mod, block RT (open inventory) when LB is pressed (for custom button combination).

**Wrong Approach** (doesn't work):
```lua
-- ❌ In PlayerController:OnControl listener (EventProcessor)
TheInput:AddControlHandler(CONTROL_OPEN_INVENTORY, function(down)
    if TheInput:IsControlPressed(CONTROL_INVENTORY_MODIFIER) then  -- LB
        return true  -- ❌ Return value ignored! Event still propagates
    end
end)
```

**Correct Approach** (works):
```lua
-- ✅ Hook PlayerHud:OnControl (in event chain)
AddClassPostConstruct("screens/playerhud", function(self)
    local OldOnControl = self.OnControl

    self.OnControl = function(hud_self, control, down)
        -- Check modifier keys first
        if TheInput:IsControlPressed(CONTROL_INVENTORY_MODIFIER) then  -- LB pressed
            if control == CONTROL_OPEN_INVENTORY then  -- RT pressed
                -- Handle custom combination
                MyMod.HandleLB_RT()
                return true  -- ✅ Block event, don't open inventory
            end
        end

        -- Normal processing
        return OldOnControl(hud_self, control, down)
    end
end)
```

**Why it works**:
1. `PlayerHud:OnControl` is in the event chain (TheFrontEnd → Screen → Widget)
2. Returning `true` consumes the event **before** it reaches other widgets or PlayerController
3. RT button won't open inventory, mod can execute custom action instead

### Mod Focus System

**Setting mod focus**:
```lua
-- In your mod screen
function MyModScreen:OnBecomeActive()
    MyModScreen._base.OnBecomeActive(self)

    -- Tell PlayerHud that mod has focus
    if ThePlayer and ThePlayer.HUD then
        ThePlayer.HUD:SetModFocus(true)
    end
end

function MyModScreen:OnBecomeInactive()
    MyModScreen._base.OnBecomeInactive(self)

    -- Release mod focus
    if ThePlayer and ThePlayer.HUD then
        ThePlayer.HUD:SetModFocus(false)
    end
end
```

**Effect**:
- `PlayerHud:HasInputFocus()` returns `true`
- PlayerController enters HUD blocking mode
- Player can still move and attack, but interactions are blocked
- Useful for mod UIs that need to coexist with gameplay

---

## PlayerController States

### IsEnabled Return Values

```lua
function PlayerController:IsEnabled()
    if self.classified == nil or not self.classified.iscontrollerenabled:value() then
        return false  -- State 1: Fully disabled
    elseif self.inst.HUD ~= nil and self.inst.HUD:HasInputFocus() then
        return false, true  -- State 2: HUD blocking mode
    end
    return true  -- State 3: Fully enabled
end
```

### Three States

| State | Returns | Movement | Combat | Interaction | UI |
|-------|---------|----------|--------|-------------|-----|
| **Fully Enabled** | `true` | ✅ | ✅ | ✅ | ✅ |
| **HUD Blocking** | `false, true` | ✅ | ✅ | ❌ | ✅ |
| **Fully Disabled** | `false` | ❌ | ❌ | ❌ | ❌ |

**Code Reference**: [scripts-raw/components/playercontroller.lua](scripts-raw/components/playercontroller.lua)

```lua
function PlayerController:OnControl(control, down)
    if IsPaused() then return end

    local isenabled, ishudblocking = self:IsEnabled()
    if not isenabled and not ishudblocking then
        return  -- Fully disabled: handle nothing
    end

    -- HUD blocking mode: limited actions allowed
    if isenabled or ishudblocking then
        if control == CONTROL_ACTION then
            self:DoActionButton()
            return
        elseif control == CONTROL_ATTACK then
            self:DoAttackButton()
            return
        end
    end

    if not isenabled then
        return  -- HUD blocking: stop here
    end

    -- Fully enabled: handle all controls
    -- ...
end
```

### HUD Blocking Mode

**Triggered when** ([scripts-raw/screens/playerhud.lua](scripts-raw/screens/playerhud.lua)):
```lua
function PlayerHud:HasInputFocus()
    local active_screen = TheFrontEnd:GetActiveScreen()
    return (active_screen ~= nil and active_screen ~= self)
        or TheFrontEnd.textProcessorWidget ~= nil
        or (self.controls ~= nil and (
            self.controls.inv.open or
            ((self:IsCraftingOpen() or
              self:IsSpellWheelOpen() or
              self:IsCommandWheelOpen()) and
             TheInput:ControllerAttached())
        ))
        or self.modfocus ~= nil
end
```

**Common scenarios**:
- Inventory open (gamepad mode)
- Crafting menu open (gamepad mode)
- Spell wheel open
- Command wheel open
- Another screen on top of HUD
- Mod sets modfocus

**Why allow movement in HUD blocking mode?**

Design decision: Players should be able to walk while browsing inventory/crafting menu (gamepad UX).

```lua
function PlayerController:OnUpdate(dt)
    local isenabled, ishudblocking = self:IsEnabled()

    if not isenabled then
        local allow_loco = ishudblocking  -- ✅ Allow movement if HUD blocking

        if allow_loco then
            -- Still predict walking
            if not self:IsBusy() then
                self:DoPredictWalking(dt)
            end
        else
            -- Stop movement
            if self.locomotor ~= nil then
                self.locomotor:Stop()
            end
        end
    end
end
```

---

## Common Patterns

### Pattern 1: Blocking Button Combination in HUD Hook

**Goal**: Block RT when modifier key (LB/RB) is pressed

```lua
-- In hud-hook.lua (PlayerHud:OnControl)
local OldHudOnControl = self.OnControl

self.OnControl = function(hud_self, control, down)
    -- Block controls when modifier keys pressed
    if Helpers.IsButtonPressed("LB") or Helpers.IsButtonPressed("RB") then
        return true  -- ✅ Consume event, prevent propagation
    end

    return OldHudOnControl(hud_self, control, down)
end
```

### Pattern 2: Lock Focus for Gamepad Inventory

**Goal**: Lock focus when inventory opens, unlock when closes

```lua
-- In inventorybar-hook.lua
function self:OpenControllerInventory()
    if not self.open then
        self.open = true
        self:SetFocus()
        G.TheFrontEnd:LockFocus(true)  -- ✅ Lock with explicit true
    end
end

function self:CloseControllerInventory()
    if self.open then
        self.open = false
        G.TheFrontEnd:LockFocus(false)  -- ✅ Unlock when closing
    end
end
```

### Pattern 3: Check Controller State in OnUpdate

**Goal**: Handle input that can't be caught by OnControl

```lua
function MyWidget:OnUpdate(dt)
    -- Always works, regardless of OnControl blocking
    if TheInput:IsControlPressed(CONTROL_ACTION) then
        self:DoAction()
    end

    -- Read analog values
    local x = TheInput:GetAnalogControlValue(CONTROL_MOVE_RIGHT) -
              TheInput:GetAnalogControlValue(CONTROL_MOVE_LEFT)
end
```

### Pattern 4: Widget Focus Management

**Goal**: Create focusable widget with proper focus forwarding

```lua
local MyContainer = Class(Widget, function(self)
    Widget._ctor(self, "MyContainer")

    -- Create actual interactive widget
    self.button = self:AddChild(Button(...))

    -- Forward focus to button
    self.focus_forward = self.button
end)

-- Or dynamic focus forwarding
self.focus_forward = function()
    return self.button:IsEnabled() and self.button or self.fallback
end
```

---

## Best Practices

### 1. Understand Which Input Path You're Working With

**Before implementing input handling**, ask:
- Is this a discrete action (button press)? → Use OnControl events
- Is this continuous input (stick movement)? → Use OnUpdate polling
- Do I need to block this input? → OnControl for buttons, hook polling for sticks

### 2. Use Correct Return Values

```lua
-- ❌ WRONG: return false to "block"
function Widget:OnControl(control, down)
    if should_block then
        return false  -- Doesn't actually block!
    end
end

-- ✅ CORRECT: return true to block
function Widget:OnControl(control, down)
    if should_block then
        return true  -- Blocks propagation
    end
end
```

### 3. Always Pair LockFocus Calls

```lua
-- ❌ WRONG: forgot to unlock
function OpenMenu()
    TheFrontEnd:LockFocus(true)
    -- Menu opened
end

-- ✅ CORRECT: unlock when closing
function OpenMenu()
    TheFrontEnd:LockFocus(true)
end

function CloseMenu()
    TheFrontEnd:LockFocus(false)
end
```

### 4. Don't Rely on OnControl for Movement

```lua
-- ❌ WRONG: won't actually block movement
function PlayerController:OnControl(control, down)
    if control == CONTROL_MOVE_UP then
        return true  -- Movement still works!
    end
end

-- ✅ CORRECT: disable PlayerController
function BlockMovement()
    ThePlayer.components.playercontroller:Enable(false)
end
```

### 5. Use Virtual Controls for Dynamic Mapping

```lua
-- ❌ WRONG: hardcoded control
if TheInput:IsControlPressed(CONTROL_PRESET_RSTICK_UP) then
    -- Doesn't work with custom mappings
end

-- ✅ CORRECT: use virtual control
if TheInput:IsControlPressed(VIRTUAL_CONTROL_INV_UP) then
    -- Automatically adapts to control scheme
end
```

### 6. Don't Mix Focus and Active Slot

```lua
-- ❌ WRONG: trying to use focus for inventorybar
if some_slot.focus then
    -- Inventorybar doesn't use focus!
end

-- ✅ CORRECT: use active_slot
if inventorybar.active_slot == some_slot then
    -- This is how inventorybar tracks selection
end
```

### 7. Be Careful with LockFocus Parameters

```lua
-- ❌ WRONG: missing parameter (nil = false = unlocked!)
TheFrontEnd:LockFocus()

-- ✅ CORRECT: explicit parameter
TheFrontEnd:LockFocus(true)   -- Lock
TheFrontEnd:LockFocus(false)  -- Unlock
```

### 8. Understand State Query Independence

```lua
-- Don't expect this pattern to work:
function Widget:OnControl(control, down)
    if control == CONTROL_ACTION then
        return true  -- Block event
    end
end

function Widget:OnUpdate(dt)
    if TheInput:IsControlPressed(CONTROL_ACTION) then
        -- ❌ This still triggers! Event blocking doesn't affect state queries
    end
end
```

### 9. Use Appropriate Hook Points

**For blocking UI-level actions**:
```lua
-- Hook TheFrontEnd:OnControl or Screen:OnControl
AddClassPostConstruct("screens/playerhud", function(self)
    local old = self.OnControl
    self.OnControl = function(self, control, down)
        if should_block then
            return true
        end
        return old(self, control, down)
    end
end)
```

**For monitoring all input**:
```lua
-- Listen to EventProcessor
TheInput:AddControlHandler(CONTROL_ACTION, function(down)
    -- This receives all events (can't block)
end)
```

### 10. Test with Both Mouse and Gamepad

Different code paths are activated:
- `TheInput:ControllerAttached()` → gamepad-specific logic
- `tracking_mouse` flag → auto-adaptation behavior
- HUD blocking mode → only active in gamepad mode for some UIs

---

## Summary

**Key Takeaways**:

1. **Two Independent Input Paths**: Events (OnControl) vs Polling (IsControlPressed/GetAnalogControlValue)
2. **Return true to Block**: In TheFrontEnd:OnControl or Widget:OnControl
3. **Can't Block Polling**: OnControl events don't affect state queries
4. **Joystick Dual Nature**: Both digital events and analog polling
5. **Focus is Tree-Level**: Parent and child must both have focus
6. **LockFocus Blocks ALL**: No focus movement when locked (but active_slot unaffected)
7. **HUD Blocking Mode**: Allows movement + combat while UI is open (gamepad UX)
8. **Inventorybar Uses Custom System**: active_slot, not Widget focus
9. **Always Pair Lock/Unlock**: LockFocus(true) must have matching LockFocus(false)
10. **Left Stick Dual Function**: Movement (analog) + Navigation (digital) work simultaneously

**Reference Files**:
- [scripts-raw/input.lua](scripts-raw/input.lua) - Core input handling
- [scripts-raw/frontend.lua](scripts-raw/frontend.lua) - UI event distribution and focus
- [scripts-raw/screens/playerhud.lua](scripts-raw/screens/playerhud.lua) - HUD controls and RT/LT handling
- [scripts-raw/components/playercontroller.lua](scripts-raw/components/playercontroller.lua) - Player controller states
- [scripts-raw/widgets/widget.lua](scripts-raw/widgets/widget.lua) - Widget focus system
- [scripts-raw/widgets/inventorybar.lua](scripts-raw/widgets/inventorybar.lua) - Custom cursor system
- [scripts-raw/events.lua](scripts-raw/events.lua) - Event processor
