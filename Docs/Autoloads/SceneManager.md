# SceneManager

**File:** `Scripts/Globals/Managers/scene_manager.gd`  
**Autoload name:** `SceneManager`  
**Load order:** 14

---

## Purpose

`SceneManager` handles **top-level scene transitions** (main menu ↔ game) and owns the **hard reset** of all simulation state. It is the safe entry point for starting a new game or returning to the main menu.

---

## Scene Paths

| Constant | Path |
|---|---|
| `MAIN_MENU_PATH` | `res://Scenes/main_menu.tscn` |
| `GAME_SCENE_PATH` | `res://Scenes/main_game.tscn` |

---

## Signals

| Signal | Payload |
|---|---|
| `scene_changed(new_scene_name)` | `"main_menu"` or `"main_game"` |

---

## Key Methods

```gdscript
# Navigate to the main menu AND wipe all game state
SceneManager.goto_main_menu()

# Navigate to the game scene (does NOT reset state — caller must do that first)
SceneManager.goto_game_scene()

# Hard reset of all global state (without changing scene)
SceneManager.reset_game_state()
```

---

## What `reset_game_state()` Does

1. Pauses time: `TimeManager.set_time_speed(PAUSED)`.
2. Resets clock to Year 740, Month 1, Day 1.
3. Clears `SimulationManager` (all characters and sects).
4. Clears `GameManager.player_char_id` and `player_sect_id`.
5. Clears `EventManager._delayed_events`.
6. Clears `WorldLogManager`.
7. Closes all `UIManager` panels.

---

## New Game Flow

```
[Setup Screen finishes]
  → SceneManager.reset_game_state()
  → CharacterGenerator.create_character() [player character]
  → SectGenerator.generate_world_sects()
  → GameManager.set_player_character(char_id)
  → SceneManager.goto_game_scene()
  → TimeManager.set_time_speed(NORMAL)
```

## Load Game Flow

```
[Player picks a save file]
  → SceneManager.reset_game_state()
  → SceneManager.goto_game_scene()
  → SaveManager.load_game(save_name)
  → TimeManager.set_time_speed(NORMAL)
```

---

## Pitfalls

- `goto_game_scene()` does **not** call `reset_game_state()`. If you navigate to the game scene without resetting first (e.g., hot-reloading during development), stale state will persist. Always call `reset_game_state()` before navigating to the game scene.
- `reset_game_state()` only resets the managers listed above. If you add new stateful autoloads in the future, you must add them to this method.
- `SceneManager` uses `get_tree().change_scene_to_file()`, which destroys the current scene immediately. Any cleanup that must happen before scene destruction should be done before calling `goto_main_menu()` or `goto_game_scene()`.

---

## Best Practices

- All "start new game" and "return to main menu" flows must go through `SceneManager` — never call `get_tree().change_scene_to_file()` directly from UI code.
- When adding new autoloads that hold persistent state (e.g., a music manager, a quest tracker), register their reset calls in `reset_game_state()`.
