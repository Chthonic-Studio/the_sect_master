# CharacterData

**File:** `Scripts/character_data_container.gd`  
**Class name:** `CharacterData` (extends `RefCounted`)

---

## Purpose

`CharacterData` is the **single container for all state belonging to one character**. It holds identity, stats, AI brain, needs, opinions, event memory, and serialization. Every character in the simulation — player or NPC, martial artist or peasant — is an instance of this class.

---

## Creating Characters

Always use `CharacterGenerator.create_character()`. Never call `CharacterData.new()` directly (except inside `SaveManager.load_game()`).

---

## Property Overview

### Identity
| Property | Type | Notes |
|---|---|---|
| `char_id` | String | Assigned by SimulationManager ("char_1", "char_2"...) |
| `first_name` | String | |
| `last_name` | String | |
| `age` | int | In years |
| `gender` | int | `Definitions.Gender` enum |
| `culture` | int | `Definitions.Culture` enum |
| `avatar_index` | int | Index into portrait sprite sheet (0–11) |

### State
| Property | Type | Notes |
|---|---|---|
| `sect_id` | String | Empty string = no sect |
| `current_realm` | int | `Definitions.MartialRealm` enum |
| `is_alive` | bool | Dead characters stay in repo but stop ticking |
| `is_martial_artist` | bool | Non-martial characters omit martial stat dictionaries |
| `aptitude` | int | `Definitions.Aptitude` enum |
| `wealth` | int | Personal coin |
| `is_hurt` | bool | Simple injury flag |
| `equipped_weapon_id` | String | Empty = no weapon equipped |

### Simulation LOD
| Tier | `SimTier` value | Behavior |
|---|---|---|
| MICRO | 0 | Full daily Utility AI, needs decay, mood calculation (on-screen) |
| MACRO | 1 | Lightweight monthly drift (off-screen background characters) |
| FROZEN | 2 | No processing at all (dead, deep secluded cultivation) |

Transition between tiers:
```gdscript
character.transition_to_micro()
character.transition_to_macro()
character.transition_to_frozen()
```

---

## Stats

### Reading Stats (Always use getters)
```gdscript
var strength: int = character.get_stat(Definitions.Stat.STRENGTH)
var insight: int  = character.get_martial_stat(Definitions.MartialStat.INSIGHT)
var ambition: int = character.get_personality_value("ambition")  # 0-100
var morality: int = character.get_alignment_value("morality")   # 0-100
```

Getters read from **cached** (`current_*`) dictionaries, not `base_*`. They are O(1).

### Base vs. Cached Stats
- `base_stats` / `base_martial` — The character's raw unmodified values.
- `current_stats` / `current_martial` — Final effective values after traits, modifiers, and weapon bonuses. **Always read these via getters.**

### Recalculating
```gdscript
character.recalculate_all_stats()
```

Called automatically when a trait or modifier is added/removed. Also called after bulk generation (world gen, loading from save). Do not call this in tight loops.

---

## Needs and State Variables

### `state_vars` (Dictionary, 0–100 floats)
| Key | Meaning |
|---|---|
| `stress` | 0 = Calm, 100 = Breakdown risk |
| `comfort` | 0 = Miserable, 100 = Luxurious |
| `loneliness` | 0 = Connected, 100 = Isolated |
| `fatigue` | 0 = Rested, 100 = Exhausted |
| `mood` | Master variable — calculated from all others |

### `needs` (Dictionary, 0–100 floats)
Key needs: `creativity, exploration, helping, relaxation, rest, shopping, training, socialization, spirituality, entertainment, studying, villainy, work`

Needs rise passively each day and are reduced by actions that fulfill them.

### Mood Calculation
Mood is derived at the end of each MICRO tick from: comfort bonus − stress penalty − fatigue penalty − loneliness penalty − highest unmet need penalty. Only the single worst unmet need penalizes mood, preventing constant despair.

---

## Traits and Modifiers

```gdscript
# Add / remove traits (triggers stat recalculation)
character.add_trait("ambitious")
character.remove_trait("ambitious")

# Add a timed modifier from the JSON registry
character.add_temporary_modifier("qi_circulation_pill", 30)  # lasts 30 days

# Add a directed opinion toward another character
character.add_directed_opinion(target_id, "gift_received", 15, 90)
```

Modifier stacking is prevented — applying the same modifier ID again refreshes the duration.

---

## Event Memory

```gdscript
# Record a memory
character.add_memory("funded_chronicle", {"cost": 50})

# Check existence
if character.has_memory("funded_chronicle"):
    pass

# Check a specific payload field
if character.has_memory_matching("funded_chronicle", "cost", 50):
    pass
```

Memory entries are stored as arrays of payload dictionaries with a `day_recorded` field added automatically.

---

## AI Tags

`ai_tags` is an `Array[String]` that determines which `Desire` objects the character evaluates. The brain only considers desires whose `ai_tags` overlap with the character's tags.

Common tags:
| Tag | Characters who have it |
|---|---|
| `general` | All characters (baseline desires) |
| `martial_artist` | All martial artists |
| `sparring` | Injected when sect builds a training hall |
| `meditator` | Injected when sect builds a meditation chamber |
| `worker` | Peasants and positioned sect members |
| `peasant` | Non-martial background characters |

---

## Death

```gdscript
character.die("old age")
```

Sets `is_alive = false`, transitions to FROZEN, logs the cause, and calls `SimulationManager.handle_character_death()` which handles sect removal and succession.

---

## Martial Awakening

```gdscript
character.awaken_martial_artist()
```

Converts a non-martial character to a martial artist: initializes all martial stat dictionaries, adds `martial_artist` AI tag, and rolls initial martial stats via `CharacterGenerator.roll_martial_awakening()`.

> **Do not read martial stats from a character where `is_martial_artist == false`.** The dictionaries are empty, and getters will return 0.

---

## Personal Log

```gdscript
character.add_log("Trained with the sword for 3 hours.")
```

Stored as a LIFO array of strings, capped at 50 entries. Each entry is prefixed with the current in-game date.

---

## Serialization

`to_dictionary()` serializes all persistent state. `from_dictionary(data)` restores it.

### Fields included in serialization
Identity, state flags, all base stats, personality/alignment values, traits, aptitude, active modifiers, personal log, wealth, directed opinions, state vars, needs, sim tier, AI tags, action cooldowns, current action (as ID + duration), current directive (as ID + duration + modifiers), equipped weapon, weapon proficiencies, event memory, next event pulse day.

> **Critical:** If you add a new persistent field to `CharacterData`, you must add it to **both** `to_dictionary()` and `from_dictionary()`. Missing either silently loses data on save/load.

### JSON key parsing note
Dictionary keys with integer enum keys (e.g., `base_stats`) are stored as strings in JSON. `from_dictionary()` converts them back: `int(key) if key.is_valid_int() else key`. This is why `base_stats` uses `Definitions.Stat.CONSTITUTION` (an int) as a key but serializes as `"0"`.

---

## Pitfalls

- **Never modify `current_stats` directly.** These are caches. Modify `base_stats` and call `recalculate_all_stats()`.
- The `directed_opinions` dictionary can grow unbounded if an NPC is involved in many interactions. Expiry cleanup runs in `process_daily_tick()` when the character is MICRO or MACRO. FROZEN characters never expire old opinions until they are unfrozen.
- `current_sim_tier` controls whether the full AI loop runs. Newly registered characters start at MICRO. WorldManager's repopulation characters start at MACRO (to save CPU on background peasants).
- Weapon proficiencies are stored with `WeaponType enum` integer keys. They serialize as string keys in JSON and must be re-parsed on load (which `from_dictionary()` handles).

---

## Best Practices

- Always check `is_alive` before processing a character from a repo.
- Check `is_martial_artist` before reading martial stats or weapon proficiencies.
- When designing systems that modify character state, prefer `add_trait()`, `add_temporary_modifier()`, and `add_directed_opinion()` over direct property mutations, as these methods handle stat recalculation and expiry automatically.
