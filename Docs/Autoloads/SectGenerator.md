# SectGenerator

**File:** `Scripts/Sects/sect_generator.gd`  
**Autoload name:** `SectGenerator`  
**Load order:** 7

---

## Purpose

`SectGenerator` generates all the sects in the world at the start of a new game. It loads hand-authored premade sects first, then dynamically fills every province with procedurally generated sects. It also runs a rival matchmaking pass to assign organic rivalries.

---

## `SectTier` Enum

| Value | int | Starting members | Resource multiplier |
|---|---|---|---|
| `MINOR` | 1 | 10–20 | ×1 |
| `AVERAGE` | 2 | 20–40 | ×2 |
| `MAJOR` | 3 | 30–60 | ×3 |
| `HEGEMON` | 4 | 40–80 | ×4 |

---

## World Generation

```gdscript
SectGenerator.generate_world_sects()
```

This is the only public entry point for world generation. It takes no parameters and performs:

1. **Load premade sects** from `DataManager.premade_sects_registry`.
2. **Populate all provinces** — every province gets sects based on the region's existing dominant reputation.
3. **Run rival matchmaking** on all dynamically generated sects.

Province population rules per province:
- **1 major sect** (unless one already exists via premade; probability reduced if a strong premade already controls the region)
- **2–5 average sects** (target reduced by regional strength)
- **3–7 minor sects** (random, minus any already present)

The "regional strength factor" is based on the highest `REPUTATION` stat among all sects already placed in that region.

---

## Creating a Single Sect

```gdscript
var sect: SectData = SectGenerator.generate_custom_sect(
    SectGenerator.SectTier.MAJOR,
    {
        "name": "Azure Dragon Sect",
        "alignment": Definitions.SectAlignment.ORTHODOX,
        "culture": Definitions.Culture.JIANGNAN,
        "province_id": "hangzhou",
        "members_count": 50
    }
)
```

Supported override keys:

| Key | Effect |
|---|---|
| `name` | Explicit sect name (skips name generation) |
| `alignment` | Explicit alignment |
| `culture` | Explicit culture |
| `province_id` | Forces placement in this province |
| `tenets` | Array of tenet IDs to assign |
| `resources` | Dictionary of `ResourceType enum → int` values |
| `laws` | Dictionary of `law_id → option_id` overrides |
| `members_count` | Override starting population count |

`generate_custom_sect()` automatically:
- Registers the sect with `SimulationManager`.
- Assigns it to the province in `MapManager`.
- Populates it with members (Sect Master + elders + disciples).
- Recalculates sect tags after tenet and law assignment.

---

## Premade Sect JSON Format

Premade sects live in `Data/Sects/default_sects.json`. Each entry supports:

```json
{
  "id": "emei_sect",
  "name": "Emei Sect",
  "alignment": "ORTHODOX",
  "culture": "SICHUAN",
  "province_id": "emei_mountains",
  "rival_sect_id": "some_evil_sect",
  "resources": { "wealth": 1000, "materials": 500 },
  "stats": { "reputation": 85, "karma": 80, "face": 40 },
  "active_tenets": ["tenet_righteous_path"],
  "relationships": { "wudang_sect": 60, "demon_cult": -80 },
  "completed_buildings": ["training_hall"]
}
```

---

## Province Population Logic (Detail)

Province population is driven by the **inverse of regional strength**:
- If a dominant premade sect (e.g., reputation 85) already controls the region, the `strength_factor` is 0.85.
- Major sect spawn chance = `1.0 - 0.85 = 0.15` (15% chance, not guaranteed).
- Average sect target = `lerp(5, 2, 0.85) ≈ 2`.
- Minor sect target = random 3–7.

This prevents overpopulating regions that already have major premade sects.

---

## Rival Matchmaking

After generation, all dynamically created sects are shuffled and greedily paired by "friction score":

- Different alignments: +50 friction.
- One Orthodox and the other Demonic/Evil: +100 friction (on top of the 50).
- Reputation difference between sects: adds `abs(rep_a - rep_b)` to friction.

The pair with the highest friction becomes rivals. Their relationship is set to `-100`. Sects without a pair simply have no assigned rival.

---

## Pitfalls

- `generate_world_sects()` must be called **after** `DataManager` is fully loaded and `MapManager.build_color_maps()` has run. In practice this is guaranteed by the autoload order, but be careful in testing scenarios where you skip autoloads.
- Premade sects' `rival_sect_id` is set from JSON but is **not** cross-checked for validity at runtime. If the referenced rival ID doesn't exist in the registry, it will stay as a dangling string.
- `_populate_sect()` creates characters and immediately registers them. At world-gen scale, this means many `register_character()` calls fire in sequence. Do not add expensive operations to `register_character()`.

---

## Best Practices

- When adding premade sects to `default_sects.json`, always specify `province_id` explicitly. If you omit it, the generator picks a province based on culture, which may cluster multiple premades in the same area.
- Use `generate_custom_sect()` for in-game spawning of new sects (e.g., a splinter sect event) — it handles all wiring automatically.
- Keep premade sect `members_count` between 20–40 for balance. The `_populate_sect()` function creates `1 master + members_count/10 elders + rest as disciples`.
