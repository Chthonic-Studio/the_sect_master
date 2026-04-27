# UIManager

**File:** `Scripts/Globals/Managers/UIManager.gd`  
**Autoload name:** `UIManager`  
**Load order:** 15

---

## Purpose

`UIManager` is the **centralized UI router**. It owns the CanvasLayer hierarchy, routes panels to correct Z-layers, manages a UI stack for Escape-key dismissal, and provides keyboard shortcuts to open/close key screens.

---

## Layer System

Layers are CanvasLayer nodes with spread Z-indices. This guarantees correct rendering order regardless of scene structure.

| Layer | Z-index | Purpose |
|---|---|---|
| `HUD = 0` | 0 | Always-visible elements (time controls, mini-map) |
| `PANELS = 1` | 10 | Heavy management screens (Sect Dashboard, Character Sheet) |
| `POPUPS = 2` | 20 | Events, confirmations, dialogs |
| `SYSTEM = 3` | 30 | Pause menu, settings |
| `TOOLTIPS = 4` | 40 | Hover information |

---

## Registering a Panel

Panels register themselves in their own `_ready()`:

```gdscript
# In character_dashboard.gd _ready()
func _ready() -> void:
    UIManager.register_panel("character_dashboard", self, UIManager.Layer.PANELS)
```

`register_panel()`:
- Adds the panel to the correct CanvasLayer.
- Hides it immediately.
- Logs an error if the ID is already registered.

---

## Opening and Closing Panels

```gdscript
# Open with optional payload
UIManager.open_panel("character_dashboard", character_data_object)
UIManager.open_panel("sect_dashboard", sect_data_object)
UIManager.open_panel("debug_screen")

# Close
UIManager.close_panel("character_dashboard")

# Close all
UIManager.close_all_panels()

# Check if open
if UIManager.is_panel_open("sect_dashboard"):
    pass
```

### Payload routing

When `open_panel()` is called with a payload:
1. If the panel has a `setup_dashboard(payload)` method, it is called.
2. Otherwise, if the panel has `setup_panel(payload)`, it is called.
3. Then the panel is shown.

---

## Spawning Popups

Popups are transient — they are instantiated on demand, added to the POPUPS layer, and free themselves when dismissed.

```gdscript
var popup_scene: PackedScene = preload("res://Scenes/UI/my_popup.tscn")
UIManager.spawn_popup(popup_scene, {"some_data": value})
```

If the popup has a `setup_popup(payload)` method, it is called after instantiation. The popup is added to the UI stack automatically and removed when its node exits the tree.

---

## Keyboard Shortcuts

| Action | Input Map Name | Behavior |
|---|---|---|
| Character screen | `char_screen` | Toggle `character_dashboard` |
| Sect screen | `sect_screen` | Toggle `sect_dashboard` |
| Debug screen | `debug_screen` | Toggle `debug_screen` (debug builds only) |
| World/map view | `world_screen` | Close all non-HUD panels, or fit map to viewport if already on map |
| Escape | `ui_cancel` | Close the topmost panel in the stack, or open `system_menu` if stack is empty |

Shortcuts are handled in `_unhandled_input()`. They consume the event with `get_viewport().set_input_as_handled()` to prevent propagation.

---

## UI Stack

The `_ui_stack` Array tracks open panels and popups in order. Pressing Escape pops the topmost node and calls `.close()` on it (if that method exists) or `.hide()`.

When `open_panel()` is called, the panel is moved to the back of the stack (topmost). If it was already in the stack, it is removed and re-appended.

---

## Event Integration

`UIManager` connects to two global signals at startup:

- `EventManager.player_event_triggered` → spawns `event_popup.tscn`, pauses time.
- `GameManager.player_succession_required` → spawns `succession_popup.tscn` on the SYSTEM layer.

---

## Signals

| Signal | Emitted when |
|---|---|
| `panel_opened(panel_id)` | Any panel is opened |
| `panel_closed(panel_id)` | Any panel is closed |
| `map_fit_requested()` | Player presses `world_screen` while already on the map |

---

## Pitfalls

- `open_panel()` guards against the panel not yet being in the scene tree with `await panel.ready`. This should not normally trigger, but if you see panels failing to open at game start, verify they have fully initialized before `register_panel()` is called.
- `close_all_panels()` closes every registered panel including the HUD. If you want to close "gameplay panels" without hiding the HUD, either skip the HUD ID in your close loop or add a flag.
- Panel IDs are plain strings with no validation. A typo in the ID will silently fail and log a `printerr`.
- The `_last_character_id` and `_last_sect_id` tracking only updates when `open_panel()` is called with a `CharacterData` or `SectData` payload. These are used by keyboard shortcuts to re-open the last viewed entity.

---

## Best Practices

- Always register panels at the `PANELS` layer unless you have a specific reason to use another. Event and system popups use `POPUPS` and `SYSTEM` respectively.
- For persistent heavy screens (Character Dashboard, Sect Dashboard), use `register_panel()` + `open_panel()`/`close_panel()`. For transient dialogs and notifications, use `spawn_popup()`.
- Every panel that opens should be dismissible via the Escape key. If your panel has complex teardown, implement a `close()` method so the stack handler can call it properly.
