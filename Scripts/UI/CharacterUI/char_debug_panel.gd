extends MarginContainer

var _info_label: Label = null
@export var vbox : VBoxContainer

func refresh_panel(character: CharacterData, _dashboard: CharacterDashboard) -> void:
	
	# Instantiate the label only once to prevent memory spikes from queue_free()
	if _info_label == null:
		for child in vbox.get_children():
			child.queue_free()
			
		_info_label = Label.new()
		vbox.add_child(_info_label)
		
	var info_text = ""
	
	info_text += "--- CURRENT AI STATE ---\n"
	info_text += "Tier: " + str(character.current_sim_tier) + "\n"
	if character.current_directive:
		info_text += "Directive: " + character.current_directive.id + " (" + str(character.current_directive.duration_remaining) + " days left)\n"
	if character.brain.current_action:
		info_text += "Action: " + character.brain.current_action.id + " (" + str(character.brain.current_action.duration_remaining) + " ticks left)\n"
	else:
		info_text += "Action: None (Evaluating)\n"
		
	info_text += "\n--- AI NEEDS (Utility Weights) ---\n"
	for need in character.needs:
		info_text += need.capitalize() + ": " + str(snapped(character.needs[need], 0.1)) + "\n"
		
	info_text += "\n--- HIDDEN PERSONALITY AXES ---\n"
	for p_key in Definitions.PERSONALITY_STATS:
		info_text += p_key.capitalize() + ": " + str(character.get_personality_value(p_key)) + "\n"
		
	_info_label.text = info_text
