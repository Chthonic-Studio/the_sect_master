extends Control

## Interactive round-by-round combat popup.
## Presented when the player character is one of the combatants in a duel.
## All static UI is defined in combat_engagement_popup.tscn.

const COMBAT_RESULT_POPUP = preload("res://Scenes/UI/combat_result_popup.tscn")

var _initiator_id: String = ""
var _target_id: String = ""
var _current_round: int = 1
var _max_rounds: int = 5

var _player_id: String = ""
var _opponent_id: String = ""

var _player_hp: float = 0.0
var _player_max_hp: float = 0.0
var _opponent_hp: float = 0.0
var _opponent_max_hp: float = 0.0

var _accumulated_narrations: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	%BtnStrikeHard.pressed.connect(func(): _on_tactic_chosen("strike_hard"))
	%BtnMeasured.pressed.connect(func():   _on_tactic_chosen("measured"))
	%BtnDefend.pressed.connect(func():    _on_tactic_chosen("defend"))
	%BtnFeint.pressed.connect(func():     _on_tactic_chosen("feint"))

func setup_popup(payload: Dictionary) -> void:
	if not is_node_ready():
		await ready

	_initiator_id = payload.get("initiator_id", "")
	_target_id    = payload.get("target_id",    "")
	_player_id    = GameManager.player_char_id

	# Determine opponent from the player's perspective
	_opponent_id = _target_id if _initiator_id == _player_id else _initiator_id

	var player: CharacterData   = SimulationManager.get_character(_player_id)
	var opponent: CharacterData = SimulationManager.get_character(_opponent_id)

	if not player or not opponent:
		queue_free()
		return

	_player_max_hp   = CombatManager._get_effective_hp(player)
	_opponent_max_hp = CombatManager._get_effective_hp(opponent)
	_player_hp       = _player_max_hp
	_opponent_hp     = _opponent_max_hp

	_refresh_status_labels()
	_add_narration_line("The clash begins. Choose your approach carefully.")

func _on_tactic_chosen(tactic: String) -> void:
	var player: CharacterData   = SimulationManager.get_character(_player_id)
	var opponent: CharacterData = SimulationManager.get_character(_opponent_id)
	if not player or not opponent:
		queue_free()
		return

	# Determine the AI opponent's tactic
	var ai_tactic: String = CombatManager.ai_choose_tactic(
		opponent, _opponent_hp, _opponent_max_hp, _player_hp, _player_max_hp)

	# Resolve round (player is always treated as "attacker" from the manager's perspective)
	var attacker: CharacterData = player
	var defender: CharacterData = opponent
	var a_tactic: String = tactic
	var d_tactic: String = ai_tactic

	# If the player was the original target (not initiator), swap roles for stat calculation
	if _initiator_id != _player_id:
		attacker = opponent
		defender = player
		a_tactic = ai_tactic
		d_tactic = tactic

	var round_result: Dictionary = CombatManager.resolve_single_round(attacker, defender, a_tactic, d_tactic)

	# Apply damage from the player's perspective
	var player_took_dmg: float = round_result.get("d_dmg", 0.0) if attacker == player else round_result.get("a_dmg", 0.0)
	var opp_took_dmg: float    = round_result.get("a_dmg", 0.0) if attacker == player else round_result.get("d_dmg", 0.0)

	_player_hp   -= player_took_dmg
	_opponent_hp -= opp_took_dmg

	var round_label: String = "Round %d — %s vs %s:" % [
		_current_round, _tactic_display(tactic), _tactic_display(ai_tactic)]
	_add_narration_line(round_label)
	_add_narration_line("  " + round_result.get("narration", ""))

	_accumulated_narrations.append(round_label)
	_accumulated_narrations.append("  " + round_result.get("narration", ""))

	_refresh_status_labels()
	_current_round += 1

	# Check for end-of-combat conditions
	if _player_hp <= 0.0 or _opponent_hp <= 0.0 or _current_round > _max_rounds:
		_finish_combat()
	else:
		%RoundLabel.text = "Round %d" % _current_round

func _finish_combat() -> void:
	_set_options_visible(false)
	%OptionsLabel.text = "The clash is decided."

	# Determine winner/loser
	var draw: bool = _player_hp <= 0.0 and _opponent_hp <= 0.0
	var winner_id: String = ""
	var loser_id: String = ""

	if not draw:
		if _opponent_hp <= 0.0 or (_player_hp > 0.0 and _player_hp >= _opponent_hp):
			winner_id = _player_id
			loser_id  = _opponent_id
		else:
			winner_id = _opponent_id
			loser_id  = _player_id

	# Build summary
	var summary: String = ""
	if draw:
		var pchar: CharacterData = SimulationManager.get_character(_player_id)
		var ochar: CharacterData = SimulationManager.get_character(_opponent_id)
		summary = "An honourable draw! Both %s and %s acknowledge each other's skill." % [
			pchar.get_full_name() if pchar else "?", ochar.get_full_name() if ochar else "?"]
	else:
		var w: CharacterData = SimulationManager.get_character(winner_id)
		var l: CharacterData = SimulationManager.get_character(loser_id)
		if w and l:
			summary = "%s has prevailed! %s concedes defeat." % [w.get_full_name(), l.get_full_name()]

	# Apply consequences via CombatManager
	var winner_delta: Dictionary = {}
	var loser_delta: Dictionary  = {}
	CombatManager._apply_duel_consequences(
		_initiator_id, _target_id, winner_id, loser_id, draw, winner_delta, loser_delta)
	CombatManager.duel_resolved.emit({
		"winner_id": winner_id, "loser_id": loser_id, "draw": draw,
		"round_narrations": _accumulated_narrations,
		"final_summary": summary,
		"winner_delta": winner_delta, "loser_delta": loser_delta
	})

	# Show the final result popup
	var result: Dictionary = {
		"winner_id": winner_id, "loser_id": loser_id, "draw": draw,
		"round_narrations": _accumulated_narrations,
		"final_summary": summary,
		"winner_delta": winner_delta, "loser_delta": loser_delta
	}
	UIManager.spawn_popup(COMBAT_RESULT_POPUP, result)
	queue_free()

func _refresh_status_labels() -> void:
	var player: CharacterData   = SimulationManager.get_character(_player_id)
	var opponent: CharacterData = SimulationManager.get_character(_opponent_id)

	var p_name: String = player.get_full_name()  if player   else "You"
	var o_name: String = opponent.get_full_name() if opponent else "Opponent"

	%AttackerName.text = p_name
	%DefenderName.text = o_name
	%AttackerHP.text   = "Qi: %d / %d" % [maxi(0, int(_player_hp)),   int(_player_max_hp)]
	%DefenderHP.text   = "Qi: %d / %d" % [maxi(0, int(_opponent_hp)), int(_opponent_max_hp)]

	# Colour attacker HP: green when healthy, yellow when hurt, red when critical
	var p_ratio: float = _player_hp / max(1.0, _player_max_hp)
	if p_ratio > 0.5:
		%AttackerHP.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif p_ratio > 0.25:
		%AttackerHP.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		%AttackerHP.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	var o_ratio: float = _opponent_hp / max(1.0, _opponent_max_hp)
	if o_ratio > 0.5:
		%DefenderHP.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	elif o_ratio > 0.25:
		%DefenderHP.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		%DefenderHP.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))

func _add_narration_line(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	%NarrationVBox.add_child(lbl)
	# Auto-scroll to the bottom
	await get_tree().process_frame
	var scroll: ScrollContainer = %NarrationVBox.get_parent()
	if scroll is ScrollContainer:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _set_options_visible(visible_state: bool) -> void:
	%OptionsContainer.visible = visible_state
	%OptionsLabel.visible = visible_state

func _tactic_display(tactic: String) -> String:
	match tactic:
		"strike_hard": return "Strike Hard"
		"measured":    return "Measured"
		"defend":      return "Defensive"
		"feint":       return "Feint"
		_:             return tactic.capitalize()
