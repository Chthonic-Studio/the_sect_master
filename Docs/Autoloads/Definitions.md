# Definitions

**File:** `Scripts/Globals/definitions.gd`  
**Autoload name:** `Definitions`  
**Load order:** 1 (first — no dependencies)

---

## Purpose

`Definitions` is the **single source of truth for all enums and constants** used across the game. It also provides helper functions to map JSON string keys into their corresponding enum integers. No game logic lives here — only data shape definitions.

---

## Enums

### `Stat` — Core character attributes
| Value | Meaning |
|---|---|
| `CONSTITUTION` | Health, physical resistance, longevity |
| `STRENGTH` | Physical damage, carrying capacity |
| `AGILITY` | Attack speed, evasion |
| `INTELLIGENCE` | Learning speed, spell potency |
| `CHARISMA` | Sect loyalty, recruitment success, social influence |

Use `Definitions.STAT_NAMES[stat_enum]` to get the lowercase string key for JSON lookups.

---

### `MartialStat` — Cultivation / internal energy stats
| Value | Meaning |
|---|---|
| `INTERNAL_FORCE` | Max Qi pool — primary power measure |
| `QI_FLOW` | Qi recovery and training speed |
| `QINGGONG` | Lightness skill (initiative, evasion) |
| `TECHNIQUE` | Execution of forms (accuracy, parry) |
| `INSIGHT` | Comprehension (counters, feints) |
| `FEROCITY` | Killing intent, crit chance |
| `DESTINY` | Luck |

Use `Definitions.MARTIAL_STAT_NAMES[stat_enum]` for the lowercase string key.

---

### `MartialRealm` — Cultivation progression tiers
`UNINITIATED → THIRD_RATE → SECOND_RATE → FIRST_RATE → PEAK_MASTER → GRANDMASTER → TRASCENDENT → SUMMIT`

> **Pitfall:** Note the typo `TRASCENDENT` (missing an 'n'). Matching this in code requires using the exact spelling. Do not correct this without a project-wide find-and-replace.

---

### `DamageType`
`SLASHING, PIERCING, BLUNT, INTERNAL, POISON, PSYCHIC`

---

### `WeaponType`
`SWORD, SABER, SPEAR, NEEDLE, STAFF, HAMMER, FIST, UNARMED, DAGGER, HIDDEN_WEAPON, FAN`

---

### `Aptitude` — Innate talent for cultivation
`MEDIOCRE, STURDY, FLEXIBLE, GENIUS, ENLIGHTENED, HEAVEN_SENT, WITHERED`

---

### `LifeState`
`HEALTHY, INJURED, INTERNAL_INJURY, CRIPPLED, MEDITATING, RETIRED, DEAD`

---

### `Gender`
`MALE, FEMALE, NON_BINARY, NON_HUMAN`

---

### `Culture`
| Value | Region |
|---|---|
| `CENTRAL_PLAINS` | Standard Han balance |
| `SICHUAN` | Poison / hidden weapon |
| `JIANGNAN` | Scholar / elegant arts |
| `LINGNAN` | Hard physical styles |
| `WESTERN_REGIONS` | Exotic, high agility |
| `NORTHERN_BORDER` | Heavy weapons, strength |
| `GORYEO` | Disciplined forms, honour-bound |

---

### `SectRank`
`LABORER → OUTER_DISCIPLE → INNER_DISCIPLE → CORE_DISCIPLE → ELDER → SECT_MASTER`

---

### `SocialClass`
`PEASANT, CITIZEN, GENTRY, NOBILITY, OUTCAST`

---

### `SectAlignment`
`ORTHODOX, DEMONIC, NEUTRAL, UNORTHODOX, EVIL`

---

### `ResourceType`
| Value | Meaning |
|---|---|
| `WEALTH` | Gold/silver for wages and purchases |
| `MATERIALS` | Wood/stone/metal for construction |
| `MEDICINE` | Healing salves, common herbs |
| `ELIXIRS` | Rare training elixirs |

---

### `SectStat`
| Value | Range | Meaning |
|---|---|---|
| `FACE` | 0–100 | Prestige spent on diplomacy |
| `REPUTATION` | 0–100 | 0 = Despised, 100 = Revered |
| `KARMA` | 0–100 | 0 = Sinful, 100 = Meritorious |

---

## Constants

### `PERSONALITY_STATS` (Array of Strings)
`ambition, honor, greed, sociability, ruthlessness, discipline, curiosity, cunning, loyalty`

These are read via `CharacterData.get_personality_value("ambition")`.

### `ALIGNMENT_STATS` (Array of Strings)
`morality, karma, reputation`

These are read via `CharacterData.get_alignment_value("morality")`.

> **Critical rule:** `morality` and `karma` modifiers in JSON **must** use the `alignment_modifiers` block, NOT `personality_modifiers`. The `DataManager.get_total_alignment_modifiers()` function looks in `alignment_modifiers` first and falls back to `personality_modifiers`, but this fallback is a compatibility shim — use `alignment_modifiers` for all new data.

### `BASE_STATS_BY_AGE`
```
child (0-12): 5
teen (13-19): 10
adult (20-60): 20
elder (60+): 15
```

### Other Constants
- `STAT_CAP = 255` — Maximum value for any base stat
- `MAX_TRAITS_PER_CHARACTER = 5`

---

## Helper Functions

These convert JSON string keys into the integer enum values used throughout the code:

```gdscript
Definitions.get_stat_enum("constitution")   # returns Definitions.Stat.CONSTITUTION
Definitions.get_martial_enum("qi_flow")     # returns Definitions.MartialStat.QI_FLOW
Definitions.get_weapon_enum("sword")        # returns Definitions.WeaponType.SWORD
Definitions.get_resource_enum("wealth")     # returns Definitions.ResourceType.WEALTH
Definitions.get_sect_stat_enum("face")      # returns Definitions.SectStat.FACE
```

All return `-1` if the string doesn't match any enum key.

---

## Best Practices

- **Always use enum values in code**, never raw integers. E.g. use `Definitions.ResourceType.WEALTH`, not `0`.
- When iterating stats in loops, use `Definitions.Stat.values()` to future-proof against new entries.
- `CULTURE_DESCRIPTIONS` is a `Dictionary` keyed by the enum *name string* (e.g., `"SICHUAN"`), not the enum integer. Use `Definitions.Culture.keys()[culture_int]` to get the key.
