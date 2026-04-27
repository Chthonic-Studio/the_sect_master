# SimulationManager

**File:** `Scripts/Globals/Managers/simulation_manager.gd`  
**Autoload name:** `SimulationManager`  
**Load order:** 5

---

## Purpose

`SimulationManager` is the **central entity store** for the entire game. It holds every character and sect in memory, drives their daily and monthly tick loops, handles deaths, and owns the sect-to-sect relationship table. It is the most performance-critical autoload.

---

## Repositories

```gdscript
SimulationManager.character_repo  # Dictionary: char_id (String) -> CharacterData
SimulationManager.sect_repo        # Dictionary: sect_id (String) -> SectData
SimulationManager.sect_relationships  # Dictionary: "sect_a|sect_b" -> int (-100 to 100)
```

> Dead characters remain in `character_repo` for history. Use `character.is_alive` to filter.

---

## Signals

| Signal | When emitted | Payload |
|---|---|---|
| `character_died(char_id)` | When any character dies | `char_id: String` |

---

## Tick Architecture

### Daily tick (character batching)

Characters are processed in **batches of `MAX_CHARACTERS_PER_FRAME = 200`** per real frame inside `_process()`. This spreads the CPU cost across multiple frames rather than freezing the game when thousands of characters tick.

**Flow per in-game day:**

1. `TimeManager.day_passed` fires → `_on_day_passed()` is called.
2. All sects process their `process_daily_tick()` immediately (few in number).
3. A snapshot of all currently alive character IDs is taken into `_active_char_ids`.
4. Over the following real frames, `_process()` burns through the snapshot batch by batch.
5. On the *next* day tick, if the previous batch hasn't finished, `_flush_remaining_characters()` force-completes it.

> **Why snapshots?** Mid-day births or deaths mutate the `character_repo`, which could corrupt iteration. The snapshot guarantees a stable processing set for that day.

### Monthly tick

`TimeManager.month_passed` fires → `_on_month_passed()` → all sects call `process_monthly_tick()`.

Characters do **not** get a monthly tick directly from here — their macro monthly logic runs inside `CharacterData._process_macro_daily()` using a modulo check on `get_total_days_elapsed()`.

---

## Character Management

```gdscript
# Register a new character (called by CharacterGenerator after creation)
SimulationManager.register_character(char_data)

# Fetch by ID (returns null if not found)
var char: CharacterData = SimulationManager.get_character("char_42")
```

`register_character()` auto-assigns an ID if the character has none, then adds the character to both `character_repo` and `_active_char_ids`.

---

## Sect Management

```gdscript
# Register a new sect (called by SectGenerator)
SimulationManager.register_sect(sect_data)

# Fetch by ID
var sect: SectData = SimulationManager.get_sect("sect_7")
```

`register_sect()` auto-assigns an ID if needed and connects the sect's `building_completed` signal to `_on_building_completed()`.

---

## Diplomacy (Sect Relationships)

```gdscript
# Get relationship score between two sects (-100 to 100). Returns 0 if no prior history.
var score: int = SimulationManager.get_sect_relationship("sect_1", "sect_2")

# Set directly
SimulationManager.set_sect_relationship("sect_1", "sect_2", -50)

# Modify by delta
SimulationManager.modify_sect_relationship("sect_1", "sect_2", -10)
```

Keys are stored alphabetically sorted (`"sect_1|sect_2"`, never `"sect_2|sect_1"`), so the order you pass the arguments doesn't matter.

A sect's relationship with itself always returns `100`.

---

## Death Handling

```gdscript
# Called internally by CharacterData.die()
SimulationManager.handle_character_death(character)
```

This method:
1. Emits `character_died` signal.
2. If the dead character is the player, calls `GameManager.trigger_player_death()`.
3. Removes the character from their sect via `sect.remove_member()`.
4. If the dead character was the Sect Master, calls `sect.handle_succession()`.
5. Removes the character from `_active_char_ids` (stops daily processing).
6. Does **not** remove the character from `character_repo` (they stay for history/memory queries).

---

## Clear & Reset

```gdscript
SimulationManager.clear_simulation()
```

Wipes all repos and resets counters. Called by `SceneManager.reset_game_state()` before a new game or load. Always call `reset_game_state()` rather than `clear_simulation()` directly, because the scene manager also resets other dependent managers.

---

## Building Completion Hook

When a `SectData` emits `building_completed`, `_on_building_completed()` reads the building's `unlocks_sect_tags` array and injects the corresponding `ai_tags` into all living sect members. This is how new buildings unlock new AI behaviors (e.g., a training hall unlocks the `"sparring"` tag).

Tag mapping (defined inside `_on_building_completed`):
| Sect tag | Member AI tag injected |
|---|---|
| `sparring`, `martial_training`, `advanced_forms` | `"sparring"` |
| `basic_meditation`, `deep_cultivation`, `qi_refinement_chamber` | `"meditator"` |
| `well_fed_disciples` | `"worker"` |

---

## Pitfalls

- **Never iterate `character_repo` directly** while potentially modifying it. Always use a snapshot: `var keys = character_repo.keys().duplicate()`. The daily tick already does this for you internally.
- **Do not call `clear_simulation()` alone** — always call `SceneManager.reset_game_state()` to ensure all dependent managers are cleaned too.
- The `building_completed` signal connection is set up in `register_sect()`. If you create a `SectData` object and add it to the repo manually (bypassing `register_sect()`), buildings will never fire their completion signal.

---

## Best Practices

- Always use `get_character(id)` and `get_sect(id)` instead of direct dictionary access. They return `null` cleanly rather than crashing on a missing key.
- Filter dead characters with `character.is_alive` before processing. The repo intentionally retains dead characters.
- For new systems that need per-day updates, connect to `TimeManager.day_passed` directly rather than tunneling through `SimulationManager`.
