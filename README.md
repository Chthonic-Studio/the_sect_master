# The Sect Master
### Tagline
Forge a Sect. Cultivate Power. Shape Destinies. Your wisdom guides their spirit, your leadership builds their strength.

## Project Description
The Sect Master: A 2D management simulation RPG set in a vibrant Wuxia-inspired universe. Players step into the shoes of a newly appointed Sect Master, tasked with the monumental challenge of transforming their fledgling sect into the most powerful force across the realm. The game offers a deep, emergent narrative experience where strategic decisions in administration, member cultivation, mission assignment, and defense will directly shape the sect's destiny and its standing in the martial world.

## Key Features
Sect Master Role: Lead your sect through intricate management, balancing growth, defense, and internal politics. Your actions influence everything from member morale to inter-sect relations.

### Dynamic Combat Simulation
Experience large-scale sect battles through detailed simulations and controlled through a strategic planning layer. For the player character (Sect Master), engage in a unique, narrative-driven turn-based/text-based combat system inspired by the Crusader Kings III: Tours & Tournaments DLC, where outcomes impact sect prestige and member mood.

### Crusader Kings-Style Succession
The Sect Master is not immortal. Experience a deep character succession system where your current Sect Master can die from age, combat, failed breakthroughs, or even assassinations. Choose your successor, navigate sect inheritance laws, and manage elder opinions to ensure a smooth transition of power. An option to retire your Sect Master to become an unplayable Elder NPC adds to the legacy.

### Autonomous & Trait-Driven Characters
All characters, including sect members and rival sect masters, are procedurally generated. They operate with independent decision-making driven by a sophisticated Utility AI coupled with a Desire/Need system, influenced by hidden personality stats reflected through visible character traits (similar to Crusader Kings III). Players can attempt to influence character traits through dialogue and training.

## In-Depth Sect Management

### Procedural Rival Sects: 
Encounter diverse rival sects, each with distinct Western or Traditional naming conventions and unique behaviors influenced by granular belief systems (akin to Stellaris ethics or Crusader Kings religions).

### Internal Politics: 
Navigate complex power dynamics within your sect. Your ability to sway elders on critical decisions (e.g., changing beliefs, declaring war) is crucial, as disgruntled elders may attempt to overthrow you.

### City-Building: 
Develop and expand your sect's physical base with a simple yet strategic city-building system for managing infrastructure and specialized buildings.

### Resource & Inventory Systems: 
Manage sect-wide and individual character inventories. Resource allocation for your Sect Master's training and equipment will compete with the needs of the wider sect, potentially leading to discontent among members and elders.

### Layered Progression: 
Advance your sect through individual character cultivation and enlightenment, unlock new abilities and bonuses via extensive technology trees, and expand your influence by growing your sect's influence in the jianghu.

### Intuitive UI/UX: 
The user interface is designed for clarity and functionality, drawing inspiration from the data-rich UIs of Stellaris (for sect-wide management and beliefs) and Rimworld (with a detailed character log allowing players to track recent actions, including hidden activities discoverable through in-game means like high perception or covert operations).

## Inspirations
### Crusader Kings (Paradox Interactive)
Core influence for character systems, succession mechanics, emergent narrative, and player character combat.

### Stellaris (Paradox Interactive)
Inspiration for grand strategy elements, procedural faction generation, technology trees, and UI design.

### Rimworld (Ludeon Studios)
Influence for autonomous character AI (Desires/Needs), individual inventories, and detailed character logs.

Wuxia Literature: The foundational thematic and aesthetic inspiration for politics, martial arts sects, progression, and the pursuit of power and immortality.

---

## Documentation Library

All technical documentation, guides, and references for *The Sect Master* are collected below.

### 📚 Technical Documentation

The [`Docs/`](Docs/README.md) folder is the main hub for codebase documentation — covering every autoload singleton, core data container, and gameplay system.

#### Autoload Singletons

| Autoload | Description |
|---|---|
| [Definitions](Docs/Autoloads/Definitions.md) | All enums, constants, and stat name maps |
| [TimeManager](Docs/Autoloads/TimeManager.md) | In-game clock, speed control, day/month/year signals |
| [DataManager](Docs/Autoloads/DataManager.md) | JSON data loading, registries, mod support, validation |
| [SaveManager](Docs/Autoloads/SaveManager.md) | Save/load game state to JSON |
| [SimulationManager](Docs/Autoloads/SimulationManager.md) | Character & sect repos, daily tick, death handling |
| [CharacterGenerator](Docs/Autoloads/CharacterGenerator.md) | Procedural character creation |
| [SectGenerator](Docs/Autoloads/SectGenerator.md) | World-gen sect creation and province population |
| [GameManager](Docs/Autoloads/GameManager.md) | Player identity, sect authority, succession signals |
| [EventManager](Docs/Autoloads/EventManager.md) | Pulse engine, event triggering, conditions, effects |
| [WorldManager](Docs/Autoloads/WorldManager.md) | World population replenishment |
| [InteractionManager](Docs/Autoloads/InteractionManager.md) | Player right-click action registry |
| [OpinionManager](Docs/Autoloads/OpinionManager.md) | Dynamic character relationship scoring |
| [WorldLogManager](Docs/Autoloads/WorldLogManager.md) | Global event log |
| [SceneManager](Docs/Autoloads/SceneManager.md) | Scene transitions and full state reset |
| [UIManager](Docs/Autoloads/UIManager.md) | Panel routing, layer management, keyboard shortcuts |
| [MapManager](Docs/Autoloads/MapManager.md) | Province/region colour maps, hover tracking, ownership |

#### Core Systems

| System | Description |
|---|---|
| [CharacterData](Docs/Systems/CharacterData.md) | The character container: stats, AI, needs, serialization |
| [SectData](Docs/Systems/SectData.md) | The sect container: economy, politics, construction, succession |
| [AI System](Docs/Systems/AI_System.md) | CharacterBrain, Desire, ActionPlan, Directive, Blackboard |

---

### 🗺️ Content & Data Guides

| Guide | Description |
|---|---|
| [Event Creation Guide](Data/Events/README.md) | How to write and chain events in JSON — pulse system, conditions, effects, dynamic text |
| [Modding Guide](Data/Modding/README.md) | How to create Data Mods (JSON traits/items) and Logic Mods (packed GDScript) |
