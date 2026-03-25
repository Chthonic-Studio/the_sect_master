# 📜 The Sect Master: Event Creation Guide

Events in *The Sect Master* drive the narrative progression of the world. They are completely decoupled from hardcoded logic, meaning you can create complex, branching narratives purely using JSON.

Events are stored in `Data/Events/`. The `EventManager` automatically scans this folder, so you can split your events across as many `.json` files as you like (e.g., `combat_events.json`, `sect_politics.json`).

---

## 1. Anatomy of an Event

An Event consists of metadata, display text, and an array of **Options**. Each Option has **Effects** and **AI Weights**.

```json
{
	"event_id": {
		"id": "event_id",
		"title": "Title shown in UI",
		"description": "Text describing what happened. Supports [dynamic_variables].",
		"options": {
			"option_key": {
				"text": "What the button says.",
				"ai_base_weight": 10.0,
				"ai_weight_modifiers": [],
				"effects": []
			}
		}
	}
}
```

---

## 2. Dynamic Text Variables
The `description` and `text` fields support dynamic string replacement based on the `context` dictionary passed when the event is triggered.

* `[initiator_name]` : The full name of the character who caused the event.
* `[target_name]` : The full name of the secondary character involved.
* `[initiator_sect_name]` : The name of the initiator's sect.
* `[target_sect_name]` : The name of the target character's sect.

---

## 3. AI Weights & Conditions
If an NPC triggers an event (e.g., an Elder making a decision off-screen), the AI will calculate the weight of every option and pick the highest one.

You can modify base weights using `condition` arrays. A condition is structured as `["check_type", "context_target", "value"]`.

**Supported Conditions:**
* `["has_trait", "initiator", "trait_id"]`
  *(Checks if the initiator has a specific string trait).*
* `["stat_greater_than", "target", "stat_name", 70]`
  *(Checks if the target character has a personality or alignment value greater than X).*

**Example AI Modifier:**
```json
"ai_weight_modifiers": [
	{ "condition": ["has_trait", "initiator", "ruthless"], "multiplier": 3.0 },
	{ "condition": ["stat_greater_than", "initiator", "ambition", 70], "add": 20.0 }
]
```

---

## 4. Effects
Effects are executed immediately when an option is selected (by a Player or AI). 

**Currently Supported Effects:**

* **Add Trait:** Gives a character a trait from `traits_registry`.
  `{ "type": "add_trait", "target": "initiator", "trait": "injured" }`

* **Modify Wealth:** Directly alters a character's personal wealth.
  `{ "type": "modify_wealth", "target": "target", "amount": -50 }`

* **Add Personal Log:** Writes a string to the character's internal Rimworld-style history.
  `{ "type": "add_personal_log", "target": "initiator", "text": "I humiliated [target_name] today." }`

* **Add World Log:** Broadcasts a major event to the global CK3-style ledger.
  `{ "type": "add_world_log", "log_type": "politics", "text": "[initiator_sect_name] declared war!" }`

* **Modify Sect Relationship:** Alters the diplomatic score between two sects.
  `{ "type": "modify_sect_relationship", "amount": -30 }`
  *(Note: This requires both `initiator_sect` and `target_sect` IDs to be present in the trigger context).*