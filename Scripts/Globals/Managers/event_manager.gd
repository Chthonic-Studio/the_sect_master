extends Node

signal player_event_triggered(event_id: String, context: Dictionary)

var _delayed_events: Array[Dictionary] = []

func _ready() -> void:
	TimeManager.day_passed.connect(_process_delayed_events)

# --- THE PULSE ENGINE ---

## Called organically by CharacterData based on their jittered offset.
func evaluate_character_pulse(character: CharacterData) -> void:
	var valid_events = []
	var context = { "initiator": character.char_id }
	
	# 1. Filter by Pulse type and Trigger Conditions
	for event_id in DataManager.events_registry:
		var event_data = DataManager.events_registry[event_id]
		if event_data.get("pulse", "") != "monthly_character":
			continue
			
		if _check_condition(event_data.get("trigger_conditions", []), context):
			valid_events.append(event_data)
			
	if valid_events.is_empty():
		return
		
	# 2. Weighted Lottery
	var total_weight = 0.0
	var weighted_pool = []
	
	for e_data in valid_events:
		var weight = e_data.get("base_weight", 1.0)
		for mod in e_data.get("weight_modifiers", []):
			if _check_condition(mod.get("condition", []), context):
				weight *= mod.get("multiplier", 1.0)
				weight += mod.get("add", 0.0)
				
		if weight > 0:
			weighted_pool.append({"event": e_data, "weight": weight})
			total_weight += weight
			
	# If no events have weight, abort
	if total_weight <= 0.0: return
	
	# The Roll
	var roll = randf_range(0.0, total_weight)
	var current = 0.0
	var chosen_event = null
	
	for item in weighted_pool:
		current += item["weight"]
		if roll <= current:
			chosen_event = item["event"]
			break
			
	# 3. Fire the chosen event
	if chosen_event:
		trigger_event(chosen_event["id"], context)

# --- CORE EVENT LOGIC ---

func trigger_event(event_id: String, context: Dictionary) -> void:
	if not DataManager.events_registry.has(event_id):
		printerr("EventManager: Event ID not found -> ", event_id)
		return
		
	var event_data = DataManager.events_registry[event_id]
	var initiator_id = context.get("initiator", "")
	var initiator = SimulationManager.get_character(initiator_id)
	
	if not initiator: return
	
	# Auto-resolve a target if the event requires one but the context doesn't provide one
	if not context.has("target") and _event_requires_target(event_data):
		var target_id = _find_valid_target(initiator)
		if target_id == "":
			return # No valid target found, abort the event
		context["target"] = target_id
	
	# Auto-logging if event is marked significant
	if event_data.get("world_log_category", "") != "":
		WorldLogManager.add_log(event_data["world_log_category"], _format_string(event_data.get("description", ""), context))
	
	# Dynamic check against the true player entity
	var is_player = GameManager.is_player(initiator.char_id)
	
	if is_player and event_data.has("options"):
		player_event_triggered.emit(event_id, context)
	else:
		_resolve_ai_event(event_data, context)

func _resolve_ai_event(event_data: Dictionary, context: Dictionary) -> void:
	var options = event_data.get("options", {})
	if options.is_empty():
		_execute_effects(event_data.get("effects", []), context)
		return
		
	var best_option_id = ""
	var highest_weight = -999.0
	
	for opt_id in options:
		var opt_data = options[opt_id]
		var base_weight = opt_data.get("ai_base_weight", 10.0)
		
		for mod in opt_data.get("ai_weight_modifiers", []):
			if _check_condition(mod.get("condition", []), context):
				base_weight *= mod.get("multiplier", 1.0)
				base_weight += mod.get("add", 0.0)
				
		base_weight *= randf_range(0.9, 1.1)
		
		if base_weight > highest_weight:
			highest_weight = base_weight
			best_option_id = opt_id
			
	if best_option_id != "":
		_execute_effects(options[best_option_id].get("effects", []), context)

func select_player_option(event_id: String, option_id: String, context: Dictionary) -> void:
	var event_data = DataManager.events_registry.get(event_id, {})
	var options = event_data.get("options", {})
	
	if options.has(option_id):
		_execute_effects(options[option_id].get("effects", []), context)

# --- EFFECTS ROUTER ---

func _execute_effects(effects: Array, context: Dictionary) -> void:
	for effect in effects:
		var type = effect.get("type", "")
		var target_key = effect.get("target", "initiator")
		var actual_id = context.get(target_key, "")
		
		match type:
			"add_trait":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.add_trait(effect["trait"])
			"modify_wealth":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.wealth += effect["amount"]
			"add_memory":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.add_memory(effect["memory_id"], effect.get("payload", {}))
			"trigger_event":
				var trigger_day = TimeManager.get_total_days_elapsed() + effect.get("delay_days", 0)
				_delayed_events.append({
					"event_id": effect["event_id"],
					"context": context.duplicate(),
					"trigger_day": trigger_day
				})
			"add_personal_log":
				var char_obj = SimulationManager.get_character(actual_id)
				if char_obj: char_obj.add_log(_format_string(effect["text"], context))
			"modify_sect_relationship":
				var init_sect = context.get("initiator_sect", "")
				var targ_sect = context.get("target_sect", "")
				if init_sect != "" and targ_sect != "":
					SimulationManager.modify_sect_relationship(init_sect, targ_sect, effect.get("amount", 0))
			"add_world_log":
				var log_type = effect.get("log_type", "Event")
				var text = _format_string(effect.get("text", ""), context)
				WorldLogManager.add_log(log_type, text)
			_:
				printerr("EventManager: Unknown effect type '", type, "' in _execute_effects. Effect payload: ", effect)

func _process_delayed_events(_day: int) -> void:
	var current_day = TimeManager.get_total_days_elapsed()
	
	# Iterate in reverse and remove in-place. Since we already iterate back-to-front,
	# we can safely remove_at(i) immediately without corrupting earlier indices.
	for i in range(_delayed_events.size() - 1, -1, -1):
		if _delayed_events[i]["trigger_day"] <= current_day:
			trigger_event(_delayed_events[i]["event_id"], _delayed_events[i]["context"])
			_delayed_events.remove_at(i)

# --- CONDITIONS & UTILS ---

## Evaluates arrays. E.g., ["has_trait", "initiator", "arrogant"] or nested lists.
func _check_condition(condition: Array, context: Dictionary) -> bool:
	if condition.is_empty(): return true
	
	# Handle nested array of conditions (AND logic)
	if condition[0] is Array:
		for sub_cond in condition:
			if not _check_condition(sub_cond, context): return false
		return true
		
	var type = condition[0]
	
	match type:
		"has_trait":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			return char_obj and char_obj.traits.has(condition[2])
		"not_has_trait":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			return char_obj and not char_obj.traits.has(condition[2])
		"has_memory":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			return char_obj and char_obj.has_memory(condition[2])
		"has_memory_matching":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			return char_obj and char_obj.has_memory_matching(condition[2], condition[3], condition[4])
		"stat_greater_than":
			var char_obj = SimulationManager.get_character(context.get(condition[1], ""))
			if not char_obj: return false
			var stat_name: String = condition[2]
			var threshold: float = condition[3]
			var val: float = 0.0
			
			if stat_name in Definitions.PERSONALITY_STATS: val = char_obj.get_personality_value(stat_name)
			elif stat_name in Definitions.ALIGNMENT_STATS: val = char_obj.get_alignment_value(stat_name)
			elif Definitions.get_stat_enum(stat_name) != -1: val = char_obj.get_stat(Definitions.get_stat_enum(stat_name))
			elif Definitions.get_martial_enum(stat_name) != -1: val = char_obj.get_martial_stat(Definitions.get_martial_enum(stat_name))
			return val > threshold
	return false

func _format_string(text: String, context: Dictionary) -> String:
	var formatted = text
	
	if context.has("initiator"):
		var c = SimulationManager.get_character(context["initiator"])
		if c: 
			formatted = formatted.replace("[initiator_name]", c.get_full_name())
			var sect = SimulationManager.get_sect(c.sect_id)
			formatted = formatted.replace("[initiator_sect_name]", sect.sect_name if sect else "Rogue Cultivators")
			
	if context.has("target"):
		var c = SimulationManager.get_character(context["target"])
		if c: 
			formatted = formatted.replace("[target_name]", c.get_full_name())
			var sect = SimulationManager.get_sect(c.sect_id)
			formatted = formatted.replace("[target_sect_name]", sect.sect_name if sect else "Rogue Cultivators")
			
	# Fallbacks in case the event only passes the sect IDs and no characters (like global world events)
	if context.has("initiator_sect") and "[initiator_sect_name]" in formatted:
		var sect = SimulationManager.get_sect(context["initiator_sect"])
		if sect: formatted = formatted.replace("[initiator_sect_name]", sect.sect_name)
		
	if context.has("target_sect") and "[target_sect_name]" in formatted:
		var sect = SimulationManager.get_sect(context["target_sect"])
		if sect: formatted = formatted.replace("[target_sect_name]", sect.sect_name)
		
	return formatted

## Returns true if the event's description or effects reference a "target" role.
func _event_requires_target(event_data: Dictionary) -> bool:
	if "[target_name]" in event_data.get("description", ""):
		return true
	for effect in event_data.get("effects", []):
		if effect.get("target", "") == "target":
			return true
	for opt_id in event_data.get("options", {}):
		var opt = event_data["options"][opt_id]
		for effect in opt.get("effects", []):
			if effect.get("target", "") == "target":
				return true
	return false

## Finds a valid living character in the same sect (or the world) to serve as an event target.
func _find_valid_target(initiator: CharacterData) -> String:
	# Prefer someone in the same sect for social events
	if initiator.sect_id != "":
		var sect = SimulationManager.get_sect(initiator.sect_id)
		if sect:
			var candidates = sect.all_members.duplicate()
			candidates.shuffle()
			for cid in candidates:
				if cid == initiator.char_id:
					continue
				var c = SimulationManager.get_character(cid)
				if c and c.is_alive:
					return cid
	return ""
