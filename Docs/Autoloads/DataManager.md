# DataManager

**File:** `Scripts/Globals/Managers/data_manager.gd`  
**Autoload name:** `DataManager`  
**Load order:** 3

---

## Purpose

`DataManager` loads **all JSON data** from `res://Data/` and `user://Mods/`, holds it in registries that every other system reads, and provides calculator helper functions for applying stat modifiers. It also hot-loads AI script files and acts as the **Action/Directive Factory**.

---

## Registries

All registries are populated during `_ready()` before any other autoload can access them (DataManager is load-order 3).

| Registry | Key | Contents |
|---|---|---|
| `traits_registry` | trait_id (string) | Trait data dictionaries |
| `name_pools` | Nested dict by culture and gender | Name arrays |
| `modifiers_registry` | modifier_id (string) | Modifier data dictionaries |
| `weapons_registry` | weapon_id (string) | Weapon stats (pre-parsed to enum keys) |
| `events_registry` | event_id (string) | Event definitions |
| `premade_sects_registry` | sect_id (string) | Hand-authored sects |
| `sect_laws_registry` | law_id (string) | Law definitions and options |
| `buildings_registry` | building_id (string) | Building costs, yields, unlocks |
| `tenets_registry` | tenet_id (string) | Tenet definitions |
| `sect_names_registry` | Nested by base/culture/alignment | Name part pools |
| `regions_registry` | region_id (string) | Region data (culture, mask_color) |
| `provinces_registry` | province_id (string) | Province data (region_id, neighbours, mask_color) |
| `micro_desires` | ai_tag (string) → Array[Desire] | Desire instances by tag |
| `macro_desires` | ai_tag (string) → Array[Desire] | Macro desire instances by tag |
| `action_scripts_registry` | action_id (string) → Script | Action script references |
| `directive_scripts_registry` | directive_id (string) → Script | Directive script references |

---

## Data Load Pipeline

Loading happens in this order in `load_all_data()`:

1. **Mount mod packs** — scans `user://Mods/` for `.zip`/`.pck` files and mounts them into `res://`.
2. **Vanilla data** — JSON from `res://Data/Traits`, `Names`, `Modifiers`, `Weapons`, `Events`, `Sects`, `Laws`, `Buildings`, `Tenets`, `SectNames`, `Map`.
3. **Mod data** — Same directories under `user://Mods/` overwrite or extend vanilla (mods loaded after vanilla).
4. **AI scripts** — GDScript files from `res://Scripts/AI/Desires`, `Actions`, and `Directives` are instantiated and registered.
5. **Validation** — `_validate_loaded_data()` runs on traits, modifiers, and events.

> **Note:** Files prefixed with `debug_` in a data directory are skipped in production (non-debug) builds.

---

## Mod Support

### JSON mods
Drop JSON files in `user://Mods/<Category>/`. IDs matching a vanilla entry overwrite it. New IDs are added to the pool. Name pools are deep-merged (arrays appended, not replaced).

### Logic mods (AI scripts)
Pack your Godot project's AI scripts as a `.zip`/`.pck` export and place it in `user://Mods/`. The game mounts the pack, and the script scanner auto-registers any new `Desire`, `ActionPlan`, or `Directive` subclasses found at the expected paths.

See `Data/Modding/README.md` for the full modding guide.

---

## Calculator Functions

These are called by `CharacterData.recalculate_all_stats()` to build the final effective stat values from base values + trait/modifier bonuses.

```gdscript
DataManager.get_total_stat_modifiers(trait_ids, modifier_ids, Definitions.Stat.STRENGTH)
DataManager.get_total_martial_modifiers(trait_ids, modifier_ids, Definitions.MartialStat.INSIGHT)
DataManager.get_total_personality_modifiers(trait_ids, modifier_ids, "ambition")
DataManager.get_total_alignment_modifiers(trait_ids, modifier_ids, "morality")
```

All return `int` deltas that are added to the base value.

---

## Action / Directive Factory

```gdscript
# Instantiate a known action by string ID (used by CharacterBrain on load)
var action: ActionPlan = DataManager.create_action("action_rest", duration_remaining)

# Instantiate a known directive
var dir: Directive = DataManager.create_directive("directive_explore_ruins", 30, {})
```

If the ID is unknown, both functions log an error and return a bare fallback instance to prevent crashes.

---

## Combat Helper

```gdscript
var mult: float = DataManager.get_weapon_matchup_multiplier("iron_sword", "bamboo_staff")
# Returns 1.5 (advantage), 0.75 (disadvantage), or 1.0 (neutral)
```

---

## Validation

On startup `DataManager` warns about:
- Unknown keys in `stat_modifiers`, `martial_modifiers`, `personality_modifiers`, `alignment_modifiers` blocks (typos).
- Unknown effect `type` strings in event effects arrays.

These produce `push_warning()` messages (yellow in Godot output), not hard errors, so the game keeps running.

---

## Pitfalls

- **Weapon data is pre-parsed at load time.** `weapons_registry` stores enum integer keys in `stat_modifiers` and `martial_modifiers`, not strings. Do not try to look up by string key after load.
- **Alignment modifiers must use `alignment_modifiers` block**, not `personality_modifiers`. The `get_total_alignment_modifiers()` function falls back to `personality_modifiers` for legacy compatibility, but new data should always use the correct block.
- **`name_pools` is a nested dictionary**, not keyed by simple ID. Access pattern: `DataManager.name_pools["cultures"]["SICHUAN"]["male_given"]`.
- Registries are populated during `_ready()`. If you try to access a registry before DataManager's `_ready()` runs (e.g., in another autoload with a lower load order), you will get empty dictionaries.

---

## Best Practices

- Read registries as read-only. Never modify a registry entry at runtime — create wrappers or override systems if you need runtime overrides.
- When checking if a data ID is valid, use `DataManager.traits_registry.has(id)` before accessing.
- When adding a new JSON data category, add both the vanilla scan path and the mod scan path to `load_all_data()`, and add the mod directory to `_ensure_mod_directories()`.
