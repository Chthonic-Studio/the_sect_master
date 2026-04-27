# TimeManager

**File:** `Scripts/Globals/Managers/time_manager.gd`  
**Autoload name:** `TimeManager`  
**Load order:** 2

---

## Purpose

`TimeManager` runs the in-game clock and drives the entire simulation via signals. Every system that needs to update over time listens to one of its signals rather than polling in `_process`.

---

## State

| Property | Type | Default | Meaning |
|---|---|---|---|
| `year` | int | 740 | Current in-game year |
| `month` | int | 1 | 1–12 |
| `day` | int | 1 | 1–30 |
| `current_speed` | Speed | PAUSED | Current time speed |

---

## Signals

| Signal | When emitted | Payload |
|---|---|---|
| `day_passed(day)` | Every in-game day | Current `day` int |
| `month_passed(month)` | Every 30 days | Current `month` int |
| `year_passed(year)` | Every 12 months | Current `year` int |
| `speed_changed(new_speed)` | When speed changes | `Speed` enum value |

### How to use signals

```gdscript
func _ready() -> void:
    TimeManager.day_passed.connect(_on_day_passed)
    TimeManager.year_passed.connect(_on_year_passed)

func _on_day_passed(_day: int) -> void:
    # runs every in-game day
    pass
```

---

## Enums

### `Speed`
| Value | Real seconds per in-game day |
|---|---|
| `PAUSED = 0` | ∞ (frozen) |
| `NORMAL = 1` | 3.0 seconds |
| `FAST = 2` | 1.0 second |
| `SUPER_FAST = 3` | ~0.43 seconds |

---

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `DAYS_PER_MONTH` | 30 | Standardized calendar |
| `MONTHS_PER_YEAR` | 12 | |
| `SECONDS_PER_DAY` | 3.0 | Baseline real-time cost per game day at NORMAL speed |
| `MAX_TICKS_PER_FRAME` | 30 | CPU death-spiral limiter |

---

## Key Methods

```gdscript
TimeManager.set_time_speed(TimeManager.Speed.FAST)   # change speed
TimeManager.toggle_pause()                            # toggle between PAUSED and NORMAL
TimeManager.get_date_string()                        # "Year 740, Month 3, Day 15"
TimeManager.get_total_days_elapsed()                 # absolute epoch day count (for expiry math)
```

---

## How the Clock Works

`_process(delta)` accumulates real seconds into `_time_accumulator`. Each time the accumulator exceeds `SECONDS_PER_DAY`, one in-game day is ticked. A multiplier based on `current_speed` scales how fast time accumulates.

### Death-spiral prevention

If the CPU falls behind (e.g., a lag spike causes the accumulator to hold many pending days), `MAX_TICKS_PER_FRAME = 30` caps how many days can be processed per real frame. If the cap is hit, the overflow time is discarded and a `printerr` is written.

---

## Pitfalls

- **Do not modify `year`, `month`, `day` directly** during gameplay — only `SceneManager.reset_game_state()` and `SaveManager.load_game()` do this for controlled reset/load flows.
- `_epoch_day` is the internal absolute day counter. Use `get_total_days_elapsed()` to read it safely. Direct `_epoch_day` access is only done by `SaveManager` during serialization.
- `day_passed` fires with the *new* day value, not the delta. Do not use it to count elapsed days — use `get_total_days_elapsed()`.

---

## Best Practices

- Always use `get_total_days_elapsed()` for expiration timestamps (modifiers, opinions, events). Never calculate `year * 360 + month * 30 + day` manually.
- Pause the game with `set_time_speed(Speed.PAUSED)` before opening any modal popup that blocks gameplay.
- Connect to `month_passed` for monthly AI updates and economy ticks (cheaper than daily).
