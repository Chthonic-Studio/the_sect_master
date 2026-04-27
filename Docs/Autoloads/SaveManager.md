# SaveManager

**File:** `Scripts/Globals/Managers/save_manager.gd`  
**Autoload name:** `SaveManager`  
**Load order:** 4

---

## Purpose

`SaveManager` serializes the entire game state to a JSON file on disk and restores it. It is the single place that reads from and writes to `user://Saves/`.

---

## Save File Location

`user://Saves/<save_name>.json`

On most platforms `user://` maps to:
- **Windows:** `%APPDATA%\Godot\app_userdata\The Sect Master\`
- **Linux:** `~/.local/share/godot/app_userdata/The Sect Master/`
- **macOS:** `~/Library/Application Support/Godot/app_userdata/The Sect Master/`

---

## Saving

```gdscript
SaveManager.save_game("my_save")
# Creates user://Saves/my_save.json
```

### What is saved

| Field | Source |
|---|---|
| `time.year/month/day/epoch_day` | `TimeManager` |
| `player_char_id` | `GameManager` |
| `simulation.next_char_id` | `SimulationManager` |
| `simulation.next_sect_id` | `SimulationManager` |
| `simulation.characters` | All characters via `CharacterData.to_dictionary()` |
| `simulation.sects` | All sects via `SectData.to_dictionary()` |
| `simulation.sect_relationships` | `SimulationManager.sect_relationships` |
| `simulation.delayed_events` | `EventManager._delayed_events` |
| `world_logs` | `WorldLogManager.global_logs` |

---

## Loading

```gdscript
SaveManager.load_game("my_save")
```

### Load order

1. Restore `TimeManager` state (year, month, day, epoch_day).
2. Clear simulation (`SimulationManager.clear_simulation()`).
3. Restore `sect_relationships` and `delayed_events`.
4. Restore `next_char_id` and `next_sect_id` counters.
5. Reconstruct all `CharacterData` objects from dictionaries. Add alive characters to `_active_char_ids`.
6. Reconstruct all `SectData` objects from dictionaries.
7. Restore `player_char_id` via `GameManager.set_player_character()`.
8. Clear and restore `WorldLogManager` logs.

> After loading, `SimulationManager.register_sect()` is **not called** during sect reconstruction — `sect_repo` is populated directly to avoid overwriting already-restored sect IDs. The `building_completed` signal is explicitly reconnected for each loaded sect immediately after deserialization.

---

## Save Headers (Load Game Screen)

```gdscript
var headers: Array[Dictionary] = SaveManager.get_all_save_headers()
# Each entry:
# {
#   "filename": "my_save",
#   "player_name": "Wei Zhen",
#   "year": 742,
#   "month": 3,
#   "day": 15
# }
```

Headers are sorted most-recent first by date.

---

## Serialization Contract

All gameplay state must be in `CharacterData.to_dictionary()` / `from_dictionary()`. The contract is strict — any field omitted from serialization is **silently lost** on save/load. See the [CharacterData documentation](../Systems/CharacterData.md) for the full list of fields.

---

## Pitfalls

- **`CharacterBrain.current_action` is not directly serialized as an object.** `to_dictionary()` saves `action_id` and `action_duration_remaining` as plain strings/ints. On load, `CharacterBrain.restore_action_state()` reconstructs the action via `DataManager.create_action()`. If you add a new `ActionPlan` subclass, the ID-based round-trip must work.
- **`SectData.active_proposals` is not currently serialized.** Any ongoing elder votes at save time are lost on load. This is a known gap.
- The `delayed_events` array stores plain dictionaries (no GDScript objects). Do not store non-serializable data in event contexts.
- Loading does not call `SceneManager.reset_game_state()` first. The caller (UI) is responsible for ensuring the scene is in a clean state before loading.

---

## Best Practices

- Always check that `SaveManager.save_game()` and `load_game()` are called **after** the game scene is active, not from the main menu scene — the game managers need to be ready.
- Call `SceneManager.reset_game_state()` before `load_game()` to ensure no stale simulation data leaks.
- When extending `CharacterData` or `SectData` with new persistent fields, always update both `to_dictionary()` and `from_dictionary()` in the same commit to keep them in sync.
