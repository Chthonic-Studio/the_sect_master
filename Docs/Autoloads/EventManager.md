# EventManager

**File:** `Scripts/Globals/Managers/event_manager.gd`  
**Autoload name:** `EventManager`  
**Load order:** 9

---

## Purpose

`EventManager` runs the **narrative event engine**. It evaluates which events are valid for a character, selects one via a weighted lottery, fires its effects, and routes player-facing events to the UI while AI characters resolve theirs silently.

---

## Signals

| Signal | When emitted | Payload |
|---|---|---|
| `player_event_triggered(event_id, context)` | When a player-character event fires | `event_id: String`, `context: Dictionary` |

`UIManager` listens to this signal and spawns `event_popup.tscn`.

---

## The Pulse System

Events do not fire every day. Instead, each character has a `next_event_pulse_day` property that is jittered between 20 and 40 days. When that day arrives, `evaluate_character_pulse()` is called for that character.

### Flow

1. `CharacterData.process_daily_tick()` checks if `current_total_days >= next_event_pulse_day`.
2. `EventManager.evaluate_character_pulse(character)` is called.
3. All events with `"pulse": "monthly_character"` are filtered for validity via `trigger_conditions`.
4. Valid events enter a weighted lottery. `base_weight` sets the base probability; `weight_modifiers` adjust it up or down based on conditions.
5. One event is chosen and `trigger_event()` is called.
6. `next_event_pulse_day` is reset to `current_total_days + random(20, 40)`.

---

## Triggering an Event Manually

```gdscript
EventManager.trigger_event("court_poet_proposal", {"initiator": some_char.char_id})
```

The context dictionary must contain at minimum `"initiator"` with a valid `char_id`. Other keys (`"target"`, `"initiator_sect"`, `"target_sect"`) are added automatically when needed.

---

## Event Data Format

See `Data/Events/README.md` for the full authoring guide. Quick reference:

```json
{
  "id": "event_id_string",
  "pulse": "monthly_character",
  "trigger_conditions": [ ["has_trait", "initiator", "ambitious"] ],
  "base_weight": 5.0,
  "weight_modifiers": [ { "condition": [...], "multiplier": 2.0, "add": 0.0 } ],
  "world_log_category": "politics",
  "description": "...",
  "options": {
    "opt_accept": {
      "text": "...",
      "ai_base_weight": 50.0,
      "ai_weight_modifiers": [...],
      "effects": [...]
    }
  }
}
```

---

## Conditions Reference

Conditions are arrays used in `trigger_conditions` and `ai_weight_modifiers`.

| Syntax | Meaning |
|---|---|
| `["has_trait", "initiator", "arrogant"]` | Initiator has this trait |
| `["not_has_trait", "initiator", "arrogant"]` | Initiator does NOT have this trait |
| `["has_memory", "initiator", "memory_id"]` | Initiator has this memory |
| `["has_memory_matching", "initiator", "memory_id", "key", "value"]` | Memory exists with matching payload field |
| `["stat_greater_than", "initiator", "strength", 80]` | Stat exceeds threshold |
| Nested array | All sub-conditions must pass (AND logic) |

Context keys used as the subject: `"initiator"` or `"target"`.

> **Pitfall:** The `stat_greater_than` condition supports personality stats (e.g., `"ambition"`), alignment stats (e.g., `"morality"`), core stats (e.g., `"strength"`), and martial stats (e.g., `"insight"`). Use the exact lowercase string names.

---

## Effects Reference

Effects live inside `options[opt_id].effects` or the root `effects` array.

| `type` | Required fields | Action |
|---|---|---|
| `add_trait` | `trait`, `target` | Adds a trait to the target character |
| `modify_wealth` | `amount`, `target` | Adds/subtracts wealth from the target character |
| `add_memory` | `memory_id`, `payload`, `target` | Records a historical memory |
| `trigger_event` | `event_id`, `delay_days` | Schedules a chained event |
| `add_personal_log` | `text`, `target` | Adds a line to the character's personal log |
| `modify_sect_relationship` | `amount` | Modifies sect relationship (needs `initiator_sect` and `target_sect` in context) |
| `add_world_log` | `log_type`, `text` | Writes to the global WorldLog |

---

## Dynamic Text Variables

Use these placeholders in `description` and option `text` fields:

- `[initiator_name]` — Full name of the initiator
- `[target_name]` — Full name of the target
- `[initiator_sect_name]` — Initiator's sect name
- `[target_sect_name]` — Target's sect name

---

## Delayed Events

`trigger_event` effects with `delay_days > 0` are stored in `_delayed_events` and processed each day. They are also saved and loaded by `SaveManager`.

---

## Player Option Resolution

When the player chooses an option in the event popup:
```gdscript
EventManager.select_player_option(event_id, option_id, context)
```

This executes the effects of the chosen option.

---

## Pitfalls

- Events without `"options"` are **immediate** — they fire their root `effects` array the moment they trigger, with no UI popup. If you want a player popup, always define an `"options"` block.
- If `trigger_event()` cannot find a valid target (needed by the event but no eligible character exists in the sect), it silently aborts. This can make events appear "not firing" — check whether the event needs a target.
- `_delayed_events` is a list of plain dictionaries saved in the JSON. Do not store non-serializable references in event contexts — only use strings and primitives.
- The weighted lottery does not guarantee any event fires. If the pool is empty after filtering, nothing happens.

---

## Best Practices

- Keep `base_weight` low (1–10) for rare narrative events. Use `weight_modifiers` to increase probability for characters with matching traits, rather than raising the base weight.
- Always define AI option weights (`ai_base_weight`) even for player-facing events. When an NPC triggers the same event, they will use those weights to auto-resolve it.
- For world events (sect-level, no specific character initiator), pass `"initiator_sect"` and `"target_sect"` instead of character IDs.
