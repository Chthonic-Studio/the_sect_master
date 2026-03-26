extends Node

## Processes JSON-defined events, handles AI option selection, and triggers effects.

signal player_event_triggered(event_id: String, context: Dictionary)

## Fires an event. The context MUST contain the "initiator" character ID, 
## but can also include "target" character ID, "target_sect" ID, etc.
func trigger_event(event_id: String, context: Dictionary) -> void:
	if not DataManager.events_registry.has(event_id):
		printerr("EventManager: Event ID not found -> ", event_id)
		return
		
	var event_data = DataManager.events_registry[event_id]
	var initiator_id = context.get("initiator", "")
	var initiator = SimulationManager.get_character(initiator_id)
	
	if not initiator: return
	
	# Future-Proofing: Determine if this character is the player.
	# (For now, we assume if they are the Sect Master of the player's sect, it's a player event).
	# Note: You will eventually want an `is_player` boolean on CharacterData.
	var is_player = (initiator.ai_tags.has("player_character")) 
	
	if is_player and event_data.has("options"):
		# Send to UI for player decision
		player_event_triggered.emit(event_id, context)
	else:
		# AI Auto-Resolution based on weights
		_resolve_ai_event(event_data, context)

## AI evaluates which option to pick based on their traits/stats.
func _resolve_ai_event(event_data: Dictionary, context: Dictionary) -> void:
	var options = event_data.get("options", {})
	if options.is_empty():
		# Hidden/No-choice events just execute their effects immediately
		_execute_effects(event_data.get("effects", []), context)
		return
		
	var _initiator = SimulationManager.get_character(context["initiator"])
	var best_option_id = ""
	var highest_weight = -999.0
	
	for opt_id in options:
		var opt_data = options[opt_id]
		var base_weight = opt_data.get("ai_base_weight", 10.0)
		
		# Modify weight based on personality/traits
		for mod in opt_data.get("ai_weight_modifiers", []):
			if _check_condition(mod.get("condition", []), context):
				base_weight *= mod.get("multiplier", 1.0)
				base_weight += mod.get("add", 0.0)
				
		# Add a tiny bit of noise so they aren't perfectly predictable
		base_weight *= randf_range(0.9, 1.1)
		
		if base_weight > highest_weight:
			highest_weight = base_weight
			best_option_id = opt_id
			
	if best_option_id != "":
		_execute_effects(options[best_option_id].get("effects", []), context)

## Exposed function for the UI to call when the player clicks an option button.
func select_player_option(event_id: String, option_id: String, context: Dictionary) -> void:
	var event_data = DataManager.events_registry.get(event_id, {})
	var options = event_data.get("options", {})
	
	if options.has(option_id):
		_execute_effects(options[option_id].get("effects", []), context)

# --- EFFECT ROUTER ---
func _execute_effects(effects: Array, context: Dictionary) -> void:
	for effect in effects:
		var type = effect.get("type", "")
		var target_key = effect.get("target", "initiator")
		
		# Resolve the actual ID based on the context string (e.g. "target" -> "char_5")
		var actual_id = context.get(target_key, "")
		
		match type:
			"add_trait":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.add_trait(effect["trait"])
				
			"modify_wealth":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.wealth += effect["amount"]
				
			"add_personal_log":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.add_log(_format_string(effect["text"], context))
				
			"add_world_log":
				WorldLogManager.add_log(effect.get("log_type", "general"), _format_string(effect["text"], context))
				
			"modify_sect_relationship":
				# --- Use safe lookups to prevent hard crashes ---
				var init_sect = context.get("initiator_sect", "")
				var targ_sect = context.get("target_sect", "")
				
				if init_sect != "" and targ_sect != "":
					SimulationManager.modify_sect_relationship(
						init_sect, 
						targ_sect, 
						effect.get("amount", 0)
					)
				else:
					printerr("EventManager: Failed to modify relationship. Missing sect keys in context.")
				
			_:
				printerr("EventManager: Unknown effect type: ", type)

# --- UTILITIES ---

## Evaluates complex logic arrays like: ["has_trait", "initiator", "arrogant"]
func _check_condition(condition: Array, context: Dictionary) -> bool:
	if condition.is_empty(): return true
	var type = condition[0]
	
	match type:
		"has_trait":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			return char_obj and char_obj.traits.has(condition[2])
		"stat_greater_than":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			if not char_obj: return false
			
			var stat_name: String = condition[2]
			var threshold: float = condition[3]
			var val: float = 0.0
			
			# --- ADDED: Dynamic stat routing ---
			if stat_name in Definitions.PERSONALITY_STATS:
				val = char_obj.get_personality_value(stat_name)
			elif stat_name in Definitions.ALIGNMENT_STATS:
				val = char_obj.get_alignment_value(stat_name)
			else:
				var stat_enum = Definitions.get_stat_enum(stat_name)
				if stat_enum != -1: 
					val = char_obj.get_stat(stat_enum)
				else:
					var martial_enum = Definitions.get_martial_enum(stat_name)
					if martial_enum != -1: 
						val = char_obj.get_martial_stat(martial_enum)
			# -----------------------------------
			
			return val > threshold
	return false

## Replaces bracketed variables with actual names. 
## E.g., "Sect Master [initiator_name] sneered."
func _format_string(text: String, context: Dictionary) -> String:
	var formatted = text
	
	if context.has("initiator"):
		var c = SimulationManager.get_character(context["initiator"])
		if c: formatted = formatted.replace("[initiator_name]", c.get_full_name())
		
	if context.has("target"):
		var c = SimulationManager.get_character(context["target"])
		if c: formatted = formatted.replace("[target_name]", c.get_full_name())
		
	if context.has("initiator_sect"):
		var s = SimulationManager.get_sect(context["initiator_sect"])
		if s: formatted = formatted.replace("[initiator_sect_name]", s.sect_name)
		
	return formatted
