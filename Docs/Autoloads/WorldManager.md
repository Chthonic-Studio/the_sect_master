# WorldManager

**File:** `Scripts/Globals/Managers/world_manager.gd`  
**Autoload name:** `WorldManager`  
**Load order:** 10

---

## Purpose

`WorldManager` maintains the **world population** by scheduling new character spawns to recover from population deficit. It listens to `TimeManager` and distributes spawns across the year to avoid CPU spikes.

---

## Configuration

| Property | Type | Default | Set by |
|---|---|---|---|
| `target_world_population` | int | 3000 | Setup screen (World Settings page) |

The setup screen maps the player's population difficulty choice to this absolute number:
- Small: ~1500
- Normal: ~3000
- Large: ~5000

---

## How It Works

### Yearly reset

When `year_passed` fires:
1. Count all living characters in `SimulationManager.character_repo`.
2. Calculate `deficit = target_population - living_count`.
3. If no deficit, do nothing.
4. Cap spawns this year at `target_population * MAX_YEARLY_RECOVERY_RATE` (5%).
5. Distribute the spawn count randomly across the 360 days of the coming year (`_spawns_by_day` dictionary).

### Daily spawn

When `day_passed` fires:
1. Calculate `current_day_of_year` from `TimeManager.month` and `TimeManager.day`.
2. If any spawns are scheduled for today, call `CharacterGenerator.create_character(REPOPULATE)` for each.
3. Erase the entry from `_spawns_by_day`.

---

## Spawn Context

All `WorldManager` spawns use `CharacterGenerator.GenerationContext.REPOPULATE`. This creates non-martial peasant characters with tags `["peasant", "worker"]`. They are not assigned to any sect.

---

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `MAX_YEARLY_RECOVERY_RATE` | 0.05 | Maximum 5% of target population can respawn per year |

---

## Pitfalls

- `_spawns_by_day` is cleared at the start of each year in `_on_year_passed()`. Any spawns scheduled but not yet executed from the previous year are **lost** when the year rolls over. This is intentional — it prevents unbounded debt accumulation.
- The day-of-year calculation uses `(month - 1) * 30 + day`. The TimeManager calendar uses `DAYS_PER_MONTH = 30`, so this math is reliable.
- `WorldManager` only spawns non-martial background characters. It does not replenish martial artist populations, which must grow organically through recruitment events.

---

## Best Practices

- Adjust `target_world_population` before calling `SectGenerator.generate_world_sects()` so the initial world is populated to the correct target.
- The 5% recovery cap prevents a catastrophic die-off (e.g., everyone dies in a war) from spawning thousands of characters in one year and crashing the CPU. This is intentional.
- If you need to force-spawn characters outside of this system (e.g., for testing), call `CharacterGenerator.create_character()` directly — do not modify `_spawns_by_day` externally.
