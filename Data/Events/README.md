# 📜 The Sect Master: Event Creation Guide

Events in *The Sect Master* drive the narrative progression of the world. They are completely decoupled from hardcoded logic, meaning you can create complex, branching narratives purely using JSON.

Events are evaluated via a **Staggered Pulse System**. Characters are evaluated periodically in the background, ensuring high performance while maintaining organic randomness.

---

## 1. Anatomy of an Event

An Event consists of metadata, trigger conditions, display text, and an array of **Options**. 

```json
{
	"court_poet_proposal": {
		"id": "court_poet_proposal",
		"title": "A Chronicler Approaches",
		"pulse": "monthly_character",
		"world_log_category": "", 
		"picture": "gfx_monk_writing",
		"requires_pause": true,
		"trigger_conditions": [
			["stat_greater_than", "initiator", "wealth", 100],
			["not_has_trait", "initiator", "humble"]
		],
		"base_weight": 5.0,
		"weight_modifiers": [
			{ "condition": ["has_trait", "initiator", "ambitious"], "multiplier": 2.0 }
		],
		"description": "A wandering scholar proposes to write the chronicles of [initiator_name]...",
		"options": {
			"opt_fund_him": {
				"text": "Give him patronage.",
				"ai_base_weight": 50.0,
				"effects": [
					{ "type": "modify_wealth", "target": "initiator", "amount": -50 },
					{ "type": "add_memory", "target": "initiator", "memory_id": "funded_chronicle", "payload": {"cost": 50} },
					{ "type": "trigger_event", "event_id": "chronicle_finished", "delay_days": 30 }
				]
			}
		}
	}
}
```

---

## 2. The Pulse System & Weights
*   **`pulse`**: Defines *when* the engine attempts to roll this event. 
	*   `monthly_character`: Evaluated during a character's background monthly tick.
    *   `directive_complete`: Evaluated immediately when a character finishes a directive.
*   **`base_weight`**: The MTTH (Mean Time To Happen) probability. A weight of `5.0` means a roughly 5% chance to fire when evaluated. Use `weight_modifiers` to make events more likely for certain personalities.

---

## 3. Dynamic Text Variables
The `description` and `text` fields support dynamic string replacement based on the `context` dictionary passed when the event is triggered.

* `[initiator_name]` : The full name of the character who caused the event.
* `[target_name]` : The full name of the secondary character involved.
* `[initiator_sect_name]` : The name of the initiator's sect.

---

## 4. Conditions & Queries
Conditions are used in `trigger_conditions` (to see if an event is valid) and `ai_weight_modifiers` (to change AI behavior).

* `["has_trait", "initiator", "trait_id"]`
* `["stat_greater_than", "target", "stat_name", 70]`
* `["has_memory", "initiator", "memory_id"]` *(Checks if they have done something in the past)*
* `["is_player_sect", "initiator"]` *(Checks if the character belongs to the player's sect)*

---

## 5. Event Chaining & Effects
You can chain events together using the `trigger_event` effect.

* **Trigger Delayed Event:**
  `{ "type": "trigger_event", "event_id": "rival_strikes_back", "delay_days": 15 }`

* **Add Historical Memory (Array-based):**
  `{ "type": "add_memory", "target": "initiator", "memory_id": "murders", "payload": {"victim": "[target_name]"} }`

* **World Log Injection:** If an event has `"world_log_category": "politics"`, it automatically logs upon triggering. Do not use a manual effect for this unless you want a specific hidden option to log.
