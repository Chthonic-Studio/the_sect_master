# WorldLogManager

**File:** `Scripts/Globals/Managers/world_log_manager.gd`  
**Autoload name:** `WorldLogManager`  
**Load order:** 13

---

## Purpose

`WorldLogManager` maintains a **rolling global event log** of significant world happenings — wars, successions, sect collapses, and any other event marked as noteworthy. The UI reads from this to display the chronicle panel.

---

## State

| Property | Type | Limit |
|---|---|---|
| `global_logs` | `Array[Dictionary]` | 1000 entries max |

Each log entry is a Dictionary:
```gdscript
{
    "date": "Year 740, Month 3, Day 15",  # String
    "type": "succession",                  # Lowercase string
    "message": "Wei Zhen has ascended..."  # String
}
```

---

## Signals

| Signal | When emitted | Payload |
|---|---|---|
| `log_added(log_entry)` | Every time a new entry is added | `log_entry: Dictionary` |

The UI panel connects to this signal to update live.

---

## Adding Entries

```gdscript
WorldLogManager.add_log("politics", "The Azure Dragon Sect has declared war on the Iron Fist Sect.")
WorldLogManager.add_log("succession", hero.get_full_name() + " has become the new Sect Master of " + sect.sect_name)
WorldLogManager.add_log("sect_collapse", sect.sect_name + " has collapsed.")
```

`type` is stored lowercase. Convention: use short snake_case category strings. Common values seen in the codebase:

| Type | Used for |
|---|---|
| `politics` | Diplomacy, war declarations |
| `succession` | Leadership changes |
| `sect_collapse` | Sect disbanding |
| `war_declaration` | (used in event JSON) |
| `event` | Generic notable character events |

Entries are inserted at the **front** of `global_logs` (newest first). When size exceeds 1000, the oldest entry is dropped.

---

## Clearing

```gdscript
WorldLogManager.clear_logs()
```

Called by `SceneManager.reset_game_state()` at the start of a new game and by `SaveManager.load_game()` before restoring saved logs.

---

## Serialization

`WorldLogManager.global_logs` is saved and loaded directly by `SaveManager`. Entries must remain plain dictionaries of primitives (strings and numbers only).

---

## Pitfalls

- The 1000-entry cap means very old events are silently dropped. Do not rely on the log for permanent game-state queries — that is what `event_memory` on individual characters is for.
- The `type` field is lowercased on store (`type.to_lower()`). Always treat the type as lowercase when reading or filtering.

---

## Best Practices

- Use `WorldLogManager` only for **globally significant** events that a player would want to see in the chronicle (wars, deaths, succession, sect growth milestones).
- For personal character events, use `CharacterData.add_log()` instead.
- Connect to `log_added` in UI panels rather than polling `global_logs` every frame.
