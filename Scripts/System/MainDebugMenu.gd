# MainDebugMenu.gd
# Provides buttons to spawn Mortal or Cultivator characters using CharacterManager.

extends MarginContainer
class_name MainDebugMenu

# Where to spawn new characters in world (offset to avoid overlap)
@export var spawn_position_base: Vector2 = Vector2(200, 200)
@export var spawn_offset: Vector2 = Vector2(40, 0)
var spawn_count: int = 0

# Action Logging
var current_action_name: String = "None"
var past_action_name: String = "None"

# AI Desire Values
var eat_desire_val: int = 0
var training_desire_val: int  = 0

var last_spawned_character: Node2D = null

func _ready() -> void:
	pass

# Called by the Mortal button
func _on_spawn_mortal_pressed() -> void:
	var pos = spawn_position_base + spawn_offset * spawn_count
	_spawn_character("mortal", pos)
	spawn_count += 1

# Called by the Cultivator button
func _on_spawn_cultivator_pressed() -> void:
	var pos = spawn_position_base + spawn_offset * spawn_count
	_spawn_character("cultivator", pos)
	spawn_count += 1

# Internal: Spawns a character using CharacterManager, adds to scene
func _spawn_character(type: String, pos: Vector2) -> void:
	var char_node = CharManager.create_character(type, pos)
	if char_node:
		get_tree().current_scene.add_child(char_node)
		last_spawned_character = char_node
		_update_info_panel()
		_connect_to_ai_signal() # Add this call
	else:
		push_error("Failed to create character of type: %s" % type)

func _update_info_panel(action_name: String = "") -> void:
	if not last_spawned_character:
		return
	var res = last_spawned_character.character_resource
	var ai_node = last_spawned_character.get_node_or_null("UtilityAI")
	
	# Basic Info
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Name.text = "Name: %s" % res.name_display
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Age.text = "Age: %d" % res.age
	$DebugHbox/CharSpawnDebug/VBoxContainer2/CultureGroup.text = "Culture: %s" % (str(res.culture))
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Gender.text = "Gender: %s" % (str(res.gender))
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Renown.text = "Renown: %s" % res.renown_title
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Reputation.text = "Reputation: %s" % res.reputation
	$DebugHbox/CharSpawnDebug/VBoxContainer2/SpiritualRoot.text = "Spiritual Root: %s" % (str(res.spiritual_root))
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Traits.text = "Traits: %s" % (", ".join(res.traits))
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Potential.text = "Potential: %d" % res.potential
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Health.text = "Health: %d/%d" % [res.max_hp, res.current_hp]
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Qi.text = "Qi: %d/%d" % [res.max_qi, res.current_qi]
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Strength.text = "Strength: %d" % res.strength
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Agility.text = "Agility: %d" % res.agility
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Intelligence.text = "Intelligence: %d" % res.intelligence
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Perception.text = "Perception: %d" % res.perception
	$DebugHbox/CharSpawnDebug/VBoxContainer2/Constitution.text = "Constitution: %d" % res.constitution
	# Personality
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Ambition.text = "Ambition: %d" % res.ambition
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Loyalty.text = "Loyalty: %d" % res.loyalty
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Greed.text = "Greed: %d" % res.greed
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Patience.text = "Patience: %d" % res.patience
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Aggression.text = "Aggression: %d" % res.aggression
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Cunning.text = "Cunning: %d" % res.cunning
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Diligence.text = "Diligence: %d" % res.diligence
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Courage.text = "Courage: %d" % res.courage
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Spirituality.text = "Spirituality: %d" % res.spirituality
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Resourcefulness.text = "Resourcefulness: %d" % res.resourcefulness
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Humility.text = "Humility: %d" % res.humility
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Charisma.text = "Charisma: %d" % res.charisma
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Discipline.text = "Discipline: %d" % res.discipline
	$DebugHbox/CharSpawnDebug/VBoxContainer3/Curiosity.text = "Curiosity: %d" % res.curiosity
	# Cultivator-only fields
	var is_cultivator = res is CultivatorResource
	$DebugHbox/CharSpawnDebug/VBoxContainer4/RealmProgress.text = "Realm Progress: %d" % (res.realm_progress if is_cultivator else 0)
	$DebugHbox/CharSpawnDebug/VBoxContainer4/Lifespan.text = "Lifespan: %d" % (res.lifespan if is_cultivator else 0)
	$DebugHbox/CharSpawnDebug/VBoxContainer4/Techniques.text = "Techniques: %s" % (", ".join(res.learned_techniques) if is_cultivator else "-")
	$DebugHbox/CharSpawnDebug/VBoxContainer4/QiDeviationRisk.text = "Qi Deviation Risk: %d" % (res.qi_deviation_risk if is_cultivator else 0)
	$DebugHbox/CharSpawnDebug/VBoxContainer4/BreakthroughModifier.text = "Breakthrough Mod: %d" % (res.breakthrough_modifier if is_cultivator else 0)
	$DebugHbox/CharSpawnDebug/VBoxContainer4/Affinities.text = "Affinities: %s" % (str(res.elemental_affinity) if is_cultivator else "-")
	# AI Debuging Fields

	if ai_node and ai_node.current_action:
		current_action_name = ai_node.current_action.action_name
	$DebugHbox/CharSpawnDebug/VBoxContainer4/CurrentAction.text = "Action: %s" % current_action_name
	$DebugHbox/CharSpawnDebug/VBoxContainer4/PastAction.text = "Past Action: %s" % past_action_name

	# --- Desire Scores ---
	if ai_node:
		for desire in ai_node.desires:
			if desire is EatDesire:
				eat_desire_val = desire.get_utility(last_spawned_character)
			elif desire is TrainingDesire:
				training_desire_val = desire.get_utility(last_spawned_character)

	$DebugHbox/CharSpawnDebug/VBoxContainer4/EatDesire.text = "Eat Desire: %d" % eat_desire_val
	$DebugHbox/CharSpawnDebug/VBoxContainer4/TrainingDesire.text = "Train Desire: %d" % training_desire_val
	
# Add this function to connect to the AI's signal
func _connect_to_ai_signal() -> void:
	if last_spawned_character:
		var ai_node = last_spawned_character.get_node_or_null("UtilityAI")
		if ai_node and not ai_node.is_connected("action_changed", Callable(self, "_update_info_panel")):
			ai_node.connect("action_changed", Callable(self, "_update_info_panel"))
