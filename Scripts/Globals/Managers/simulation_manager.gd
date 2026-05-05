extends Node

signal character_died(char_id: String)

# --- REPOSITORIES (The "Living Entities") ---
var character_repo: Dictionary = {}
var next_char_id: int = 1

var sect_repo: Dictionary = {}
var next_sect_id: int = 1

var sect_relationships: Dictionary = {} # Maps "sect_a|sect_b" -> int (-100 to 100)

const MAX_CHARACTERS_PER_FRAME: int = 200

# Tracks the day-snapshot of character IDs currently being processed
var _active_char_ids: Array[String] = []
var _process_index: int = 0
var _current_processing_day: int = 0

# --- WORKER THREAD POOL INTEGRATION ---
# Holds CharacterData references for the batch currently being computed in parallel.
# Replaced each frame; safe because we never modify it while the group task is running.
var _batch_chars: Array = []
# Group task ID returned by WorkerThreadPool.add_group_task(). -1 = no pending tasks.
var _batch_task_group_id: int = -1

func _ready() -> void:
	TimeManager.day_passed.connect(_on_day_passed)
	TimeManager.month_passed.connect(_on_month_passed)
	GameManager.player_character_changed.connect(_on_player_changed)

## Broadcasts the daily tick to all active characters and sects in the simulation
func _on_day_passed(_day: int) -> void:
	# Trigger Sects immediately as they are few in number
	var current_total_days = TimeManager.get_total_days_elapsed()
	var active_sect_keys = sect_repo.keys().duplicate()
	for s_id in active_sect_keys:
		if sect_repo.has(s_id):
			sect_repo[s_id].process_daily_tick(current_total_days)

	# If the previous day's batch hasn't finished processing, force-complete it
	# to prevent characters from silently missing their daily tick.
	if _process_index < _active_char_ids.size():
		_flush_remaining_characters()

	# Snapshot all currently registered characters for THIS day only.
	# This prevents mid-day repo mutations from corrupting the current batch iteration.
	_active_char_ids.clear()
	for key in character_repo.keys():
		var character = character_repo[key]
		if character.is_alive:
			_active_char_ids.append(str(key))
	_current_processing_day = current_total_days
	_process_index = 0

## Processes all remaining characters from the previous day's batch immediately.
func _flush_remaining_characters() -> void:
	# Wait for any in-flight worker batch before running the main-thread fallback.
	if _batch_task_group_id >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_batch_task_group_id)
		_apply_batch_effects()
		_batch_task_group_id = -1

	while _process_index < _active_char_ids.size():
		var char_id = _active_char_ids[_process_index]
		var character = character_repo.get(char_id)

		if character and character.is_alive:
			character.process_daily_tick(_current_processing_day)

		_process_index += 1

func _process(_delta: float) -> void:
	# --- PHASE B: Apply effects once the current compute batch finishes ---
	if _batch_task_group_id >= 0:
		if WorkerThreadPool.is_group_task_completed(_batch_task_group_id):
			_apply_batch_effects()
			_batch_task_group_id = -1
		else:
			return  # Threads still working; retry next frame

	if _process_index >= _active_char_ids.size():
		return  # All characters processed for today

	# --- PHASE A: Collect next batch and dispatch to WorkerThreadPool ---
	_batch_chars.clear()
	var count = 0
	while count < MAX_CHARACTERS_PER_FRAME and _process_index < _active_char_ids.size():
		var char_id = _active_char_ids[_process_index]
		var character = character_repo.get(char_id)
		if character and character.is_alive:
			_batch_chars.append(character)
		_process_index += 1
		count += 1

	if _batch_chars.is_empty():
		return

	# Capture a local snapshot so the lambda closure is self-contained and the
	# main thread can safely refill _batch_chars on the next dispatch.
	var snapshot: Array = _batch_chars.duplicate()
	var day: int = _current_processing_day

	_batch_task_group_id = WorkerThreadPool.add_group_task(
		func(i: int): snapshot[i].compute_daily_tick(day),
		snapshot.size()
	)
	# Store snapshot so _apply_batch_effects() can iterate the same chars.
	_batch_chars = snapshot

## Drain the pending side-effects for every character in the last completed batch.
## Called on the main thread after WorkerThreadPool confirms all tasks are done.
func _apply_batch_effects() -> void:
	for character in _batch_chars:
		# A character could have died during this same apply cycle (e.g. killed by an event
		# triggered for another character in the batch). Skip to avoid redundant effects.
		if character and character.is_alive:
			character.apply_daily_effects()
	_batch_chars.clear()

## Broadcasts the macro monthly tick to all active sects
func _on_month_passed(_month: int) -> void:
	var active_sect_keys = sect_repo.keys().duplicate()
	for s_id in active_sect_keys:
		if sect_repo.has(s_id):
			sect_repo[s_id].process_monthly_tick()

	# Age all living characters once per in-game year (12 months)
	if TimeManager.month == 1:
		_process_annual_aging()

#region Character Management
func register_character(char_data: CharacterData) -> void:
	if char_data.char_id == "":
		char_data.char_id = "char_" + str(next_char_id)
		next_char_id += 1
	character_repo[char_data.char_id] = char_data

	# Avoid duplicates when re-registering during debug/load flows.
	if not _active_char_ids.has(char_data.char_id):
		_active_char_ids.append(char_data.char_id)

func get_character(char_id: String) -> CharacterData:
	return character_repo.get(char_id, null)
#endregion

#region Sect Management
func register_sect(sect_data: SectData) -> void:
	if sect_data.sect_id == "":
		sect_data.sect_id = "sect_" + str(next_sect_id)
		next_sect_id += 1
	sect_repo[sect_data.sect_id] = sect_data
	sect_data.building_completed.connect(_on_building_completed)

func get_sect(sect_id: String) -> SectData:
	return sect_repo.get(sect_id, null)
#endregion

#region Diplomacy & Relationships

## Generates an alphabetically sorted, unique key for any two sects.
func _get_relationship_key(id_a: String, id_b: String) -> String:
	if id_a < id_b:
		return id_a + "|" + id_b
	return id_b + "|" + id_a

## Gets the relationship between two sects. Defaults to 0 if they haven't interacted.
func get_sect_relationship(id_a: String, id_b: String) -> int:
	if id_a == id_b:
		return 100 # A sect always loves itself
	var key = _get_relationship_key(id_a, id_b)
	return sect_relationships.get(key, 0)

## Sets the relationship value, clamping it between -100 and 100.
func set_sect_relationship(id_a: String, id_b: String, value: int) -> void:
	if id_a == id_b:
		return
	var key = _get_relationship_key(id_a, id_b)
	sect_relationships[key] = clampi(value, -100, 100)

## Modifies the relationship by a delta amount safely.
func modify_sect_relationship(id_a: String, id_b: String, amount: int) -> void:
	var current = get_sect_relationship(id_a, id_b)
	set_sect_relationship(id_a, id_b, current + amount)

#endregion

#region Mortality & Global Events

func handle_character_death(character: CharacterData) -> void:
	character_died.emit(character.char_id)

	# Notify GameManager if the player character has died
	if GameManager.is_player(character.char_id):
		GameManager.trigger_player_death()

	# If they belonged to a sect, we must check if succession is triggered
	if character.sect_id != "":
		var sect = get_sect(character.sect_id)
		if sect:
			# Check if the dead character was the active Sect Master BEFORE removing them
			var masters = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
			var was_master = masters.has(character.char_id)
			
			# Remove the dead character from the sect's membership records
			sect.remove_member(character.char_id)
			
			if was_master:
				sect.handle_succession()

	# We leave them in the repo for memory/history, but remove from daily processing loop
	_active_char_ids.erase(character.char_id)

#endregion

func clear_simulation() -> void:
	character_repo.clear()
	sect_repo.clear()
	sect_relationships.clear()
	next_char_id = 1
	next_sect_id = 1
	_active_char_ids.clear()
	_process_index = 0
	_current_processing_day = 0
	_batch_chars.clear()
	_batch_task_group_id = -1

## Sweeps the entire character repo and assigns each living character the correct
## SimTier: MICRO for player-sect members, MACRO for everyone else.
## Called once after world generation and whenever the player changes character.
func sync_all_sim_tiers() -> void:
	var player_sect: String = GameManager.player_sect_id
	for char_id in character_repo:
		var c: CharacterData = character_repo[char_id]
		if not c.is_alive or c.current_sim_tier == CharacterData.SimTier.FROZEN:
			continue
		if player_sect != "" and c.sect_id == player_sect:
			if c.current_sim_tier != CharacterData.SimTier.MICRO:
				c.transition_to_micro()
		else:
			if c.current_sim_tier != CharacterData.SimTier.MACRO:
				c.transition_to_macro()

func _on_player_changed(_char_id: String) -> void:
	sync_all_sim_tiers()

## Increments age for every living character and applies mortality checks.
## Called once per in-game year (when month == 1 in _on_month_passed).
func _process_annual_aging() -> void:
	var char_keys = character_repo.keys().duplicate()
	for c_id in char_keys:
		var character: CharacterData = character_repo.get(c_id)
		if not character or not character.is_alive:
			continue

		character.age += 1

		# Natural death chance: scales up steeply after age 70
		if character.age >= 70:
			var constitution: float = character.get_stat(Definitions.Stat.CONSTITUTION)
			# Base 2% at 70, +3% per year over 70, reduced by constitution
			var base_chance: float = 0.02 + (character.age - 70) * 0.03
			base_chance -= (constitution / 255.0) * 0.10 # High constitution reduces chance
			base_chance = clampf(base_chance, 0.01, 0.60)

			if randf() < base_chance:
				character.die("old age")
				WorldLogManager.add_log("social", character.get_full_name() + " has passed away at the age of " + str(character.age) + ".")

	# Periodic cleanup: remove characters dead 10+ years with no living relatives from the repo
	_prune_old_dead_characters()

## Called when a sect completes a building. Injects AI tags into members so new desires become available.
func _on_building_completed(sect: SectData, building_id: String) -> void:
	var b_data = DataManager.buildings_registry.get(building_id, {})
	var tags_to_inject: Array = b_data.get("unlocks_sect_tags", [])
	
	# Map sect-level tags to the individual ai_tags that enable new desires
	var member_tag_map: Dictionary = {
		"sparring": "sparring",
		"martial_training": "sparring",
		"advanced_forms": "sparring",
		"basic_meditation": "meditator",
		"deep_cultivation": "meditator",
		"qi_refinement_chamber": "meditator",
		"well_fed_disciples": "worker"
	}
	
	var new_member_tags: Array[String] = []
	for sect_tag in tags_to_inject:
		if member_tag_map.has(sect_tag):
			var member_tag: String = member_tag_map[sect_tag]
			if not new_member_tags.has(member_tag):
				new_member_tags.append(member_tag)
	
	if new_member_tags.is_empty():
		return
	
	# Inject the new tags into all current sect members
	for char_id in sect.all_members:
		var character = get_character(char_id)
		if character and character.is_alive:
			for tag in new_member_tags:
				if not character.ai_tags.has(tag):
					character.ai_tags.append(tag)

## Removes very old dead characters from memory to prevent unbounded repo growth.
## Only prunes characters dead 10+ in-game years with no active dependencies.
func _prune_old_dead_characters() -> void:
	var keys_to_remove: Array[String] = []
	var today: int = TimeManager.get_total_days_elapsed()
	for c_id in character_repo:
		var c: CharacterData = character_repo[c_id]
		if c.is_alive:
			continue
		if GameManager.is_player(c_id):
			continue
		# Only prune once we know the precise death day (death_day >= 0)
		if c.death_day < 0:
			continue
		if today - c.death_day > 3650: # ~10 in-game years
			keys_to_remove.append(c_id)

	for c_id in keys_to_remove:
		character_repo.erase(c_id)
