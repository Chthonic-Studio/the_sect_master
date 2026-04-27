# GameManager

**File:** `Scripts/Globals/Managers/game_manager.gd`  
**Autoload name:** `GameManager`  
**Load order:** 8

---

## Purpose

`GameManager` is a **thin identity layer** that knows who the player character is and what sect they lead. It provides the authoritative check for player actions and owns the signals that drive the death and succession UI flows.

---

## State

| Property | Type | Default |
|---|---|---|
| `player_char_id` | String | `""` |
| `player_sect_id` | String | `""` |

---

## Signals

| Signal | When emitted | Payload |
|---|---|---|
| `player_character_changed(new_char_id)` | When the player character is reassigned | `new_char_id: String` |
| `player_died(dead_char_id)` | When the player's character dies | `dead_char_id: String` |
| `player_succession_required(heir_char_id)` | When the player's Sect Master dies | `heir_char_id: String` |

---

## Key Methods

```gdscript
# Bind the player to a character (used at game start and after succession)
GameManager.set_player_character("char_1")

# Check if a character ID belongs to the player
if GameManager.is_player(char_id):
    pass

# Check if the player has authority over a sect
if GameManager.can_manage_sect(sect_id):
    pass

# Trigger death UI flow (called by SimulationManager.handle_character_death())
GameManager.trigger_player_death()

# Trigger succession UI flow (called by SectData.handle_succession())
GameManager.trigger_player_succession("char_5")
```

---

## How the Death / Succession Flow Works

1. `CharacterData.die()` → `SimulationManager.handle_character_death(character)`
2. `handle_character_death()` calls `GameManager.trigger_player_death()` if `is_player(char_id)`
3. `player_died` signal → **not connected to anything yet** — UI will listen here in a future phase.
4. If the dead character was the Sect Master, `SectData.handle_succession()` is called.
5. Succession evaluates the heir and calls `GameManager.trigger_player_succession(heir_id)`.
6. `player_succession_required` signal → `UIManager._on_player_succession_required()` → spawns `sucession_popup.tscn`.
7. Player clicks "Play as Heir" in the popup → calls `GameManager.set_player_character(heir_id)` and `SectData.execute_succession(heir_id)`.

---

## Pitfalls

- `set_player_character()` validates that the character exists in `SimulationManager`. If you call it with a bad ID, it logs an error and does **not** update `player_char_id`. Check for this when debugging unexpected state.
- `player_sect_id` is set from the character's `sect_id` at the moment `set_player_character()` is called. If the player's sect changes later (e.g., merging sects), you must call `set_player_character()` again or manually update `player_sect_id`.
- `trigger_player_death()` only emits the signal. It does **not** pause the game or open any UI directly — that is the responsibility of whatever system listens to `player_died`.

---

## Best Practices

- Use `GameManager.is_player(char_id)` wherever branching on player vs. AI is needed. Never compare `char_id == GameManager.player_char_id` inline in game-logic code — route it through the helper to keep refactoring easy.
- UI systems should react to `player_character_changed` to refresh their display rather than caching the character object directly.
