# AI System

**Files:**
- `Scripts/AI/character_brain.gd` — CharacterBrain
- `Scripts/AI/desire.gd` — Desire (base class)
- `Scripts/AI/action_plan.gd` — ActionPlan (base class)
- `Scripts/AI/directive.gd` — Directive (base class)
- `Scripts/AI/blackboard.gd` — Blackboard

---

## Overview

The AI system uses a **Utility AI** architecture. Each character continuously evaluates a set of *Desires* (scored potential behaviors) and picks the one with the highest score to execute as an *Action*. Higher-level *Directives* can override normal behavior entirely for missions, assignments, or forced states. The *Blackboard* provides a coordination layer for actions that need to reserve another character.

---

## CharacterBrain

`CharacterBrain` is a `RefCounted` stored directly inside each `CharacterData` object (`character.brain`). It is not a Node — it runs when called, with no `_process()` of its own.

### How it runs

`CharacterBrain.process_daily_tick(character)` is called once per in-game day per MICRO-tier character by `CharacterData.process_daily_tick()`.

```
process_daily_tick(character)
├── Current action exists?
│   ├── _should_interrupt_for_urgency()? → null out current_action
│   └── Else: action.process_tick(), decrement duration
│       └── Duration <= 0? → action.on_complete(), null out current_action
└── current_action == null?
    └── _choose_new_action(character)
```

### Urgency Interruption

Critical needs preempt the current action:
- `fatigue >= 90` and current action is not `action_rest`
- `loneliness >= 95` and current action is not `action_social_discussion`
- `rest_need >= 95` and current action is not `action_rest`

This mirrors RimWorld's "pawn drops everything to address a critical need."

### Action Selection

```
_choose_new_action(character)
├── Iterate over character.ai_tags
│   └── For each tag, get desires from DataManager.micro_desires[tag]
│       └── Evaluate each desire (skipping duplicates)
│           └── raw_score = desire.evaluate(character)
│               └── Apply noise variance ±15%
│                   └── Track best scoring desire
└── best_desire.generate_action(character) → assigns current_action
```

The `UTILITY_NOISE_VARIANCE = 0.15` constant prevents deterministic loops by adding random 0.85–1.15× noise to every scored desire. Characters still generally choose the most appropriate action, but not *always*.

---

## Desire

`Desire` is the base class for all evaluatable AI behaviors. Desires are `Resource` objects loaded and instantiated at startup by `DataManager`.

### Base Class Interface

```gdscript
class_name Desire extends Resource

var id: String = "base_desire"
var ai_tags: Array[String] = ["general"]
var is_macro: bool = false  # true = monthly macro evaluation; false = daily micro evaluation

func evaluate(_character: CharacterData) -> float:
    return 0.0  # Return <= 0 to skip this desire entirely

func generate_action(_character: CharacterData) -> ActionPlan:
    return null  # Return the action to execute
```

### Creating a new Desire

```gdscript
# res://Scripts/AI/Desires/desire_spar.gd
extends Desire

func _init() -> void:
    id = "desire_spar"
    ai_tags = ["martial_artist", "sparring"]  # Available to chars with EITHER tag

func evaluate(character: CharacterData) -> float:
    var training_need = character.needs.get("training", 0.0)
    if training_need < 20.0:
        return 0.0  # Not interested
    var ambition = character.get_personality_value("ambition")
    return (training_need * 0.5) + (ambition * 0.3)

func generate_action(character: CharacterData) -> ActionPlan:
    return DataManager.create_action("action_spar", 1)
```

The file will be auto-detected and registered by `DataManager._scan_directory_for_scripts()` at startup.

> **Rule:** The `evaluate()` method must NEVER access the SceneTree (`get_node()`, `get_parent()`, etc.) or allocate large objects. It runs for every character every day — keep it cheap.

### Routing: micro vs. macro
- `is_macro = false` (default): The desire is stored in `DataManager.micro_desires` and evaluated daily by `CharacterBrain`.
- `is_macro = true`: The desire is stored in `DataManager.macro_desires`. **Currently not wired** — macro desires are loaded but not evaluated yet. This is a planned future feature for off-screen macro AI.

---

## ActionPlan

`ActionPlan` is the base class for all executable behaviors. It represents an ongoing activity that takes one or more days.

```gdscript
class_name ActionPlan extends RefCounted

var id: String = "base_action"
var duration_remaining: int = 1

func _init(duration: int = 1) -> void:
    duration_remaining = duration

func process_tick(_character: CharacterData) -> void:
    pass  # Called once per day while the action is active

func on_complete(_character: CharacterData) -> void:
    pass  # Called when duration reaches 0
```

### Creating a new Action

```gdscript
# res://Scripts/AI/Actions/action_spar.gd
extends ActionPlan

func _init(duration: int = 1) -> void:
    super(duration)
    id = "action_spar"

func process_tick(character: CharacterData) -> void:
    character.needs["training"] = maxf(0.0, character.needs.get("training", 0.0) - 30.0)
    character.state_vars["fatigue"] = minf(100.0, character.state_vars.get("fatigue", 0.0) + 10.0)

func on_complete(character: CharacterData) -> void:
    # Small chance to gain internal force experience
    if randf() < 0.05:
        character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += 1
        character.recalculate_all_stats()
```

The filename becomes the action ID: `action_spar.gd` → ID `"action_spar"`.

### Serialization

Actions are serialized by ID and remaining duration only. `CharacterBrain.restore_action_state(action_id, duration)` reconstructs them on load using `DataManager.create_action()`. Any per-tick state computed inside the action is **lost on save**. Keep actions stateless beyond `duration_remaining`.

---

## Directive

`Directive` is a high-level AI override. While a character has an active directive, `CharacterBrain.process_daily_tick()` is not called — the directive runs instead.

```gdscript
class_name Directive extends RefCounted

var id: String = "base_directive"
var duration_remaining: int = 1
var decay_modifiers: Dictionary = {}

func _init(duration: int = 1, modifiers: Dictionary = {}) -> void:
    duration_remaining = duration
    decay_modifiers = modifiers

func process_tick(_character: CharacterData) -> void:
    pass  # Called once per day

func is_complete() -> bool:
    return duration_remaining <= 0

func on_complete(_character: CharacterData) -> void:
    pass  # Called when duration reaches 0 (grant rewards, clear state, etc.)
```

### `decay_modifiers` dictionary

Directives can accelerate or slow the character's daily state decay by passing a `decay_modifiers` dictionary that overrides `_apply_daily_decay()`:

```gdscript
# Example: Assign a hard training mission (tiring, stressful, but builds training need fast)
var modifiers = {
    "fatigue_rate": 15.0,   # default is 5.0
    "stress_rate": 3.0,     # stress doesn't normally rise passively
    "training_rate": 5.0    # faster training buildup
}
var directive = DataManager.create_directive("directive_mountain_training", 30, modifiers)
character.current_directive = directive
```

### Assigning a Directive

```gdscript
character.current_directive = DataManager.create_directive("directive_id", duration, modifiers)
```

The existing brain action is cleared automatically in `transition_to_frozen()` when needed. The directive is processed daily until `is_complete()`.

---

## Blackboard

`Blackboard` is a **transient coordination board** for actions that need to claim a partner or resource. It is used for social actions where two characters interact.

```gdscript
# A character advertises themselves as available for socializing
SimulationManager.blackboard.advertise("social_idle", char_id)

# An action claims the first available social partner
var target_id = SimulationManager.blackboard.claim_target("social_idle", initiator_id)

# When the action ends, release the partner
SimulationManager.blackboard.release_target("social_idle", target_id)
```

> **Important:** Blackboard data is **not saved**. After loading, characters must re-advertise themselves (which happens naturally as they begin their first MICRO tick).

### `available_entities` — Dict[tag → Array[entity_id]]
### `reserved_entities` — Dict[target_id → claimer_id]

`claim_target()` uses `pop_back()` on the array — it takes the last advertised character. If the array is empty, it returns `""` (no partner available).

`release_target()` puts the partner back into `available_entities`.

---

## Complete AI Data Flow

```
Day tick fires for a MICRO character:
  CharacterData.process_daily_tick()
    ├── Modifier expiry
    ├── Opinion expiry
    ├── Directive.process_tick() [if directive active]
    │     └── _apply_daily_decay(directive.decay_modifiers)
    └── CharacterBrain.process_daily_tick() [if no directive]
          ├── Urgency check → may null out current_action
          ├── current_action.process_tick()
          │     └── Modifies needs, state_vars, wealth, sect resources
          ├── current_action.on_complete() [when done]
          └── _choose_new_action()
                └── Evaluates all desires in matching ai_tags
                    └── best_desire.generate_action() → new current_action
```

---

## Pitfalls

- **Macro desires** (`is_macro = true`) are loaded but **not evaluated** yet. Any desire with `is_macro = true` silently does nothing until the macro evaluation loop is implemented.
- Actions are identified purely by their filename (minus extension). Two action files with the same name in different directories will silently overwrite each other in the registry.
- The `_choose_new_action()` loop iterates `character.ai_tags` and looks up `DataManager.micro_desires[tag]`. A character with many tags will evaluate many desires. Keep `evaluate()` cheap.
- If `generate_action()` returns `null`, no action is set and the brain will re-evaluate next day. This is valid for "not ready yet" cases but can cause a character to do nothing for long stretches if all desires return null.

---

## Best Practices

- Always gate `evaluate()` with a fast early-return check (e.g., check a need threshold before computing a score) to skip clearly invalid desires immediately.
- Use `Directive` for player-assigned missions, sect assignments, or forced states (imprisonment, secluded meditation). Use `Desire`/`ActionPlan` for autonomous daily behavior.
- When an action involves two characters (social), use `Blackboard` to coordinate — never directly reach into another character's brain to modify their state mid-tick.
- Keep `on_complete()` side effects small. Avoid triggering cascading stat recalculations or spawning new characters inside a completion callback.
