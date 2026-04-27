# SectData

**File:** `Scripts/Sects/sect_data_container.gd`  
**Class name:** `SectData` (extends `RefCounted`)

---

## Purpose

`SectData` is the **container for all state belonging to one sect**. It manages membership rosters, resources, economy, laws, tenets, construction, political proposals, and succession. All sect AI and economic simulation runs through or from this object.

---

## Creating Sects

Always use `SectGenerator.generate_custom_sect()` or `SectGenerator.generate_world_sects()`. Never call `SectData.new()` directly (except inside `SaveManager.load_game()`).

---

## Property Overview

### Identity
| Property | Type | Notes |
|---|---|---|
| `sect_id` | String | Assigned by SimulationManager ("sect_1", ...) |
| `sect_name` | String | Display name |
| `alignment` | int | `Definitions.SectAlignment` enum |
| `culture` | int | `Definitions.Culture` enum |
| `province_id` | String | Geographic home province |
| `rival_sect_id` | String | Primary rival (set at world gen or by events) |

### Economy
| Property | Type | Notes |
|---|---|---|
| `resources` | Dictionary[ResourceType enum → int] | WEALTH, MATERIALS, MEDICINE, ELIXIRS |
| `stats` | Dictionary[SectStat enum → int] | FACE (0–100), REPUTATION (0–100), KARMA (0–100) |
| `cached_sect_strength` | int | Rough power estimate, recalculated when membership changes |

---

## Membership Management

Membership is tracked in three parallel structures for O(1) lookups:
- `all_members` — `Array[String]` of all char_ids
- `members_by_rank` — `Dictionary[SectRank enum → Array[String]]`
- `members_by_position` — `Dictionary[String position_name → Array[String]]`

```gdscript
# Add a character
sect.add_member(char_id, Definitions.SectRank.INNER_DISCIPLE)
sect.add_member(char_id, Definitions.SectRank.ELDER, "cook")  # with a position

# Remove a character
sect.remove_member(char_id)

# Change position
sect.assign_position(char_id, "treasurer")

# Query
var elders: Array = sect.members_by_rank.get(Definitions.SectRank.ELDER, [])
var treasurers: Array = sect.members_by_position.get("treasurer", [])
```

`add_member()` scrubs the character from all existing rank arrays before assigning the new rank, preventing duplicate entries. It also calls `flag_strength_dirty()` to update `cached_sect_strength`.

---

## Economy — Monthly Tick

```gdscript
# Runs once per in-game month via SimulationManager._on_month_passed()
sect.process_monthly_tick()
```

Income and expenses are computed by `get_projected_monthly_deltas()`:
1. **Building yields** — each completed building contributes its `yields` block.
2. **Building upkeep** — each completed building subtracts its `monthly_upkeep` block.
3. **Elder stipends** — based on the `elder_stipends` law option and number of elders.

If WEALTH goes negative, it is clamped to 0 and FACE loses 5 points.

```gdscript
# Read projected deltas for UI tooltips (non-destructive)
var deltas: Dictionary = sect.get_projected_monthly_deltas()
# Returns { ResourceType.WEALTH: 150, ResourceType.MATERIALS: -30, ... }
```

---

## Laws

Laws are persistent sect rules. Each law has multiple options.

```gdscript
# Change a law directly (bypasses the council)
sect.change_law("elder_stipends", "lavish")
sect.change_law("succession", "seniority")

# Change via the council system (recommended for player actions)
sect.propose_action("change_law", {"law_id": "elder_stipends", "new_option_id": "none"})
```

`change_law()` returns `false` if the law_id or option_id don't exist. It emits `law_changed` signal on success.

### Checking Law Flags

```gdscript
# Check if the sect has a specific behavioral flag from any tenet or law
if sect.has_sect_flag("absolute_authority"):
    # Master can bypass the council
    pass
```

---

## Tenets

```gdscript
sect.add_tenet("tenet_righteous_path")   # Returns bool (false if invalid alignment or duplicate)
sect.remove_tenet("tenet_righteous_path")
```

Tenets define sect philosophy. They contribute `flags` (behavioral flags), `name_contributions` (for procedural name generation), and allowed alignment constraints. Tenets are defined in `Data/Tenets/tenets.json`.

---

## Construction

```gdscript
# Check affordability and prerequisites
if sect.can_build("training_hall"):
    sect.start_construction("training_hall")

# View the queue
for project in sect.construction_queue:
    print(project["building_id"], " — ", project["days_remaining"], " days left")

# Cancel
sect.cancel_construction(0)  # Index 0 = front of queue
```

`start_construction()` deducts resources immediately and appends to the queue. Only one project per building_id is allowed at a time.

Construction advances daily via `process_daily_tick()`. On completion:
1. The building is added to `completed_buildings`.
2. If it has a `replaces` key, the old building is removed.
3. `recalculate_sect_tags()` is called to update `unlocked_tags`.
4. `building_completed` signal is emitted → `SimulationManager._on_building_completed()` injects AI tags into all members.

---

## Sect Tags

`unlocked_tags` is derived from completed buildings and active tenets. It controls what constructions are available (via `prerequisite_tags`) and influences AI behavior.

```gdscript
sect.recalculate_sect_tags()  # Rebuild unlocked_tags from scratch
```

This is called automatically on building completion, tenet changes, and law changes.

---

## Political Proposals (Elder Council)

```gdscript
sect.propose_action("change_law", {"law_id": "succession", "new_option_id": "seniority"})
sect.propose_action("declare_war", {"target_sect_id": "sect_7"})
```

If the sect has the `absolute_authority` flag, the action executes immediately. Otherwise:
1. A `SectProposal` object is created with a 7-day deliberation window.
2. One elder votes per day (their vote is influenced by loyalty, opinion of the Sect Master, and personality).
3. On day 7 (or when all undecided elders have voted), the proposal resolves.
4. If `supporters >= opposers`, the action executes. Otherwise, it is rejected.

---

## Succession

When the Sect Master dies:

```gdscript
# Called by SimulationManager.handle_character_death()
sect.handle_succession()
```

1. Evaluates the best heir via `_evaluate_heir()` using the `succession` law:
   - `"strongest"` (default): sorts by `INTERNAL_FORCE`
   - `"seniority"`: sorts by `age`
2. If this is the player's sect: pauses time + triggers `GameManager.player_succession_required()`.
3. Otherwise (AI sect): immediately calls `execute_succession(heir_id)`.

```gdscript
# Player confirmation / manual call
sect.execute_succession(heir_id)
```

If no living members remain, `WorldLogManager` logs a sect collapse event.

---

## Signals

| Signal | When emitted |
|---|---|
| `modifier_expired(sect, modifier_id)` | A timed modifier expires |
| `strength_recalculated(sect)` | `cached_sect_strength` is updated |
| `building_completed(sect, building_id)` | A building finishes construction |
| `law_changed(sect, law_id, new_option_id)` | A law is changed |
| `tenet_added(sect, tenet_id)` | A tenet is added |
| `tenet_removed(sect, tenet_id)` | A tenet is removed |

---

## Serialization

`to_dictionary()` and `from_dictionary()` handle full save/load. Fields serialized:
- Identity (sect_id, name, alignment, culture, province_id, rival_sect_id)
- Resources and stats
- Membership (all_members, members_by_rank, members_by_position)
- State (active_laws, completed_buildings, active_modifiers, active_tenets, unlocked_tags, construction_queue)

> **Known gap:** `active_proposals` (ongoing elder votes) are **not serialized**. In-progress votes are lost on save/load.

---

## Pitfalls

- `cached_sect_strength` is recalculated every time a member is added or removed. For bulk operations (world gen), this causes O(n²) strength recalculations. Consider deferring with a dirty flag pattern if this becomes a bottleneck.
- `members_by_rank` and `members_by_position` can go out of sync if you modify `all_members` directly. Always use `add_member()` and `remove_member()`.
- The `building_completed` signal is connected in `SimulationManager.register_sect()` during normal sect creation. For sects loaded from a save file, `SaveManager` explicitly reconnects this signal after deserialization.

---

## Best Practices

- Read `get_projected_monthly_deltas()` in the UI to show income projections — never compute economy math in UI code.
- Always route player sect actions through `propose_action()` rather than directly calling `change_law()` or other mutators. This ensures the elder council mechanic fires correctly.
- When iterating `all_members` to get character objects, always guard with `SimulationManager.get_character(char_id)` and check `character.is_alive` — the array can contain IDs of dead characters while they are waiting to be cleaned up.
