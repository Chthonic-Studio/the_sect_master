# The Sect Master — System Documentation

This folder contains technical documentation for every major system and autoload in *The Sect Master*. Use it as a reference when writing new features, debugging, or onboarding into the codebase.

---

## How to Navigate

| Category | What's inside |
|---|---|
| [Autoloads](Autoloads/) | Every global singleton — what it owns, what it exposes, and how to call it |
| [Systems](Systems/) | Core data containers and gameplay loops (CharacterData, SectData, AI) |

---

## Autoload Load Order

Autoloads are listed in `project.godot` and initialize in this order at runtime. **Order matters** — later autoloads may safely call earlier ones during `_ready()`.

| # | Autoload Name | File |
|---|---|---|
| 1 | `Definitions` | `Scripts/Globals/definitions.gd` |
| 2 | `TimeManager` | `Scripts/Globals/Managers/time_manager.gd` |
| 3 | `DataManager` | `Scripts/Globals/Managers/data_manager.gd` |
| 4 | `SaveManager` | `Scripts/Globals/Managers/save_manager.gd` |
| 5 | `SimulationManager` | `Scripts/Globals/Managers/simulation_manager.gd` |
| 6 | `CharacterGenerator` | `Scripts/Globals/character_generator.gd` |
| 7 | `SectGenerator` | `Scripts/Sects/sect_generator.gd` |
| 8 | `GameManager` | `Scripts/Globals/Managers/game_manager.gd` |
| 9 | `EventManager` | `Scripts/Globals/Managers/event_manager.gd` |
| 10 | `WorldManager` | `Scripts/Globals/Managers/world_manager.gd` |
| 11 | `InteractionManager` | `Scripts/Globals/Managers/interaction_manager.gd` |
| 12 | `OpinionManager` | `Scripts/Globals/Managers/opinion_manager.gd` |
| 13 | `WorldLogManager` | `Scripts/Globals/Managers/world_log_manager.gd` |
| 14 | `SceneManager` | `Scripts/Globals/Managers/scene_manager.gd` |
| 15 | `UIManager` | `Scripts/Globals/Managers/UIManager.gd` |
| 16 | `MapManager` | `Scripts/Map/map_manager.gd` |

> **Pitfall:** Never call a lower-numbered autoload from a higher-numbered one inside `_ready()` if the earlier autoload hasn't finished initializing. The safe order above guarantees that e.g. `DataManager` is fully loaded before `SimulationManager` starts.

---

## Autoload Documentation

- [Definitions](Autoloads/Definitions.md) — All enums, constants, and stat name maps
- [TimeManager](Autoloads/TimeManager.md) — In-game clock, speed control, day/month/year signals
- [DataManager](Autoloads/DataManager.md) — JSON data loading, registries, mod support, validation
- [SimulationManager](Autoloads/SimulationManager.md) — Character & sect repos, daily tick, death handling
- [GameManager](Autoloads/GameManager.md) — Player identity, sect authority, succession signals
- [CharacterGenerator](Autoloads/CharacterGenerator.md) — Procedural character creation
- [SectGenerator](Autoloads/SectGenerator.md) — World-gen sect creation and province population
- [EventManager](Autoloads/EventManager.md) — Pulse engine, event triggering, conditions, effects
- [WorldManager](Autoloads/WorldManager.md) — World population replenishment
- [OpinionManager](Autoloads/OpinionManager.md) — Dynamic character relationship scoring
- [InteractionManager](Autoloads/InteractionManager.md) — Player right-click action registry
- [WorldLogManager](Autoloads/WorldLogManager.md) — Global event log
- [SaveManager](Autoloads/SaveManager.md) — Save/load game state to JSON
- [SceneManager](Autoloads/SceneManager.md) — Scene transitions and full state reset
- [UIManager](Autoloads/UIManager.md) — Panel routing, layer management, keyboard shortcuts
- [MapManager](Autoloads/MapManager.md) — Province/region color maps, hover tracking, ownership

---

## System Documentation

- [CharacterData](Systems/CharacterData.md) — The character container: stats, AI, needs, serialization
- [SectData](Systems/SectData.md) — The sect container: economy, politics, construction, succession
- [AI System](Systems/AI_System.md) — CharacterBrain, Desire, ActionPlan, Directive, Blackboard

---

## Global Architecture Summary

```
TimeManager ──► SimulationManager ──► CharacterData.process_daily_tick()
                                  └──► SectData.process_daily_tick()
                                  └──► SectData.process_monthly_tick()

CharacterData.process_daily_tick()
    ├── Modifier expiration
    ├── Directive tick  (if active)
    ├── CharacterBrain.process_daily_tick()  [MICRO only]
    ├── _process_macro_daily()               [MACRO only]
    └── EventManager.evaluate_character_pulse()

EventManager ──► player_event_triggered signal ──► UIManager ──► event_popup
             └──► _resolve_ai_event()
```

All gameplay data lives inside `SimulationManager.character_repo` (Dictionary) and `SimulationManager.sect_repo` (Dictionary). Everything else is derived from those two stores.
