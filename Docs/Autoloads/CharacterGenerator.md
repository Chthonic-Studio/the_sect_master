# CharacterGenerator

**File:** `Scripts/Globals/character_generator.gd`  
**Autoload name:** `CharacterGenerator`  
**Load order:** 6

---

## Purpose

`CharacterGenerator` is the **factory for all `CharacterData` objects**. It procedurally builds characters from scratch by applying demographics, talents, personality, and stats in order — then registers the result with `SimulationManager`. You should never create a `CharacterData` directly; always go through this generator.

---

## `GenerationContext` Enum

The context controls the character's role, AI tags, and starting age range.

| Context | `is_martial_artist` | AI tags | Age |
|---|---|---|---|
| `WORLD_GEN_MARTIAL` | true | `general`, `martial_artist` | Weighted adult distribution |
| `WORLD_GEN_PEASANT` | false | `peasant`, `worker` | Weighted adult distribution |
| `BIRTH` | true | `general`, `martial_artist` | 0 |
| `RECRUIT_COMMON` | true | `general`, `martial_artist` | 14–20 |
| `RECRUIT_ELITE` | true | `general`, `martial_artist` | 14–20 |
| `SECT_MEMBER` | true | `general`, `martial_artist` | override or 16–60 |
| `REPOPULATE` | false | `peasant`, `worker` | Weighted adult distribution |

---

## Creating a Character

```gdscript
# Minimal — let the generator decide everything
var char: CharacterData = CharacterGenerator.create_character(
    CharacterGenerator.GenerationContext.SECT_MEMBER
)

# With overrides
var char: CharacterData = CharacterGenerator.create_character(
    CharacterGenerator.GenerationContext.SECT_MEMBER,
    {
        "sect_id": "sect_5",
        "culture": Definitions.Culture.JIANGNAN,
        "age": 25,
        "first_name": "Ling",
        "last_name": "Zhao",
        "gender": Definitions.Gender.FEMALE
    }
)
```

`create_character()` always calls `SimulationManager.register_character()` internally — you do not need to register it yourself.

---

## Supported `overrides` Keys

| Key | Type | Effect |
|---|---|---|
| `sect_id` | String | Assigns sect; also determines culture if `culture` not provided |
| `culture` | int (Culture enum) | Explicit culture override |
| `age` | int | Explicit age |
| `gender` | int (Gender enum) | Explicit gender |
| `first_name` | String | Explicit first name |
| `last_name` | String | Explicit last name |
| `ai_tags` | Array[String] | Replaces default tags entirely |

---

## Culture Roll Distribution

When no culture is provided, the generator rolls a weighted distribution:

| Culture | Probability |
|---|---|
| CENTRAL_PLAINS | ~40% |
| JIANGNAN | ~12% |
| SICHUAN | ~12% |
| LINGNAN | ~12% |
| NORTHERN_BORDER | ~11% |
| WESTERN_REGIONS | ~11% |
| GORYEO | ~7% |

If the character belongs to a sect (`sect_id` override provided), they inherit the sect's culture instead.

---

## Martial Awakening

Non-martial characters can be converted to martial artists later:

```gdscript
character.awaken_martial_artist()
```

This sets `is_martial_artist = true`, initializes all `MartialStat` dictionaries (which are omitted for non-martial characters to save memory), and calls `CharacterGenerator.roll_martial_awakening(character)` to seed initial martial stats based on aptitude.

---

## Pitfalls

- `create_character()` calls `recalculate_all_stats()` and `register_character()` at the end. Calling them again afterward is redundant but harmless.
- Non-martial characters have **empty** `base_martial`, `current_martial`, and `weapon_proficiencies` dictionaries. Never try to read martial stats from a character where `is_martial_artist == false` — you'll get `0` from the getter, which may mislead logic.
- `GenerationContext.BIRTH` creates a character at age 0 without martial stats. An infant becoming a martial artist later must explicitly call `awaken_martial_artist()`.

---

## Best Practices

- Use the most specific context available. For sect NPC creation, prefer `SECT_MEMBER`; for world population, use `WORLD_GEN_MARTIAL` or `WORLD_GEN_PEASANT`.
- When batch-generating large populations (e.g., world gen), pass `sect_id` in overrides so the culture and name pool are inherited from the sect, producing culturally consistent members.
- The generator is the single point of character creation. Do not instantiate `CharacterData.new()` and fill it manually outside of `SaveManager.load_game()`.
