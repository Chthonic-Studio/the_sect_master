# InteractionManager

**File:** `Scripts/Globals/Managers/interaction_manager.gd`  
**Autoload name:** `InteractionManager`  
**Load order:** 11

---

## Purpose

`InteractionManager` is the registry for **player right-click actions** — things the player can do to a character (insult, sway, gift wealth, etc.). It stores `PlayerAction` objects and filters them based on validity at the moment of the interaction.

---

## Getting Valid Actions

```gdscript
var actions: Array[PlayerAction] = InteractionManager.get_valid_actions(initiator, target)
```

Returns only actions where `action.can_execute(initiator, target)` returns `true`. Use this to populate a right-click context menu for a character.

---

## Registered Actions (Current)

- `action_insult` — Reduces the target's opinion of the initiator
- `action_sway` — Attempts to improve the target's opinion of the initiator
- `action_gift_wealth` — Transfers wealth from initiator to target, improving their opinion

These are loaded in `_load_core_actions()` using hardcoded paths.

> **Known gap:** The comment in the code states that a future version will use `DataManager`'s script scanner to load actions dynamically. Currently actions must be registered manually.

---

## Creating a New Player Action

All player actions extend `Scripts/Interactions/player_action.gd`.

```gdscript
# player_action.gd base class
func can_execute(initiator: CharacterData, target: CharacterData) -> bool:
    return true  # Override with actual preconditions

func execute(initiator: CharacterData, target: CharacterData) -> void:
    pass  # Override with the action's effect
```

Then register it in `InteractionManager._load_core_actions()`:

```gdscript
registered_actions.append(load("res://Scripts/Interactions/Actions/action_my_action.gd").new())
```

---

## Pitfalls

- `get_valid_actions()` returns an empty array if `initiator == target` or if either argument is null.
- Actions are currently loaded with **hardcoded paths** in `_load_core_actions()`. If you rename a file, you must update the path here.
- There is no data-driven filtering by context (e.g., "only in the same sect"). All filtering must be implemented in each action's `can_execute()` method.

---

## Best Practices

- Each `PlayerAction` script should be self-contained. `can_execute()` should be cheap to call — no expensive loops or allocations, as it runs for every registered action every time the player opens a context menu.
- Keep side effects inside `execute()`, never in `can_execute()`.
- When an action affects opinions, use `CharacterData.add_directed_opinion()` so the change is tracked and expires naturally over time.
