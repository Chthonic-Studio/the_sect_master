extends Control
class_name DebugScreen

## Debug overlay panel. Provides a command console and real-time diagnostic tabs.
## Only fully functional in debug builds; visible to devs and modders.

const MAX_LOG_LINES := 200

var _command_history: Array[String] = []
var _history_index: int = -1
var _log_append_count: int = 0

func _ready() -> void:
	UIManager.register_panel("debug_screen", self, UIManager.Layer.SYSTEM)
	
	$MarginContainer/VBox/TitleBar/CloseButton.pressed.connect(
		func(): UIManager.close_panel("debug_screen")
	)
	
	var cmd_input: LineEdit = $MarginContainer/VBox/TabContainer/Console/CommandInput
	cmd_input.text_submitted.connect(_on_command_submitted)
	cmd_input.gui_input.connect(_on_command_input_key)
	
	# Refresh stats once per second while visible
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_stats_tab)
	add_child(timer)
	
	_log_line("[color=yellow]Debug Console ready. Type 'help' for available commands.[/color]")

func setup_panel(_payload: Variant = null) -> void:
	_refresh_stats_tab()
	_refresh_log_tab()

# --- COMMAND INPUT ---

func _on_command_submitted(text: String) -> void:
	var cmd := text.strip_edges()
	if cmd == "":
		return
	_command_history.push_back(cmd)
	_history_index = _command_history.size()
	($MarginContainer/VBox/TabContainer/Console/CommandInput as LineEdit).clear()
	_log_line("[color=cyan]> %s[/color]" % cmd)
	_execute_command(cmd)

func _on_command_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var input: LineEdit = $MarginContainer/VBox/TabContainer/Console/CommandInput
	if event.keycode == KEY_UP:
		if _command_history.size() > 0:
			_history_index = maxi(_history_index - 1, 0)
			input.text = _command_history[_history_index]
			input.set_caret_column(input.text.length())
	elif event.keycode == KEY_DOWN:
		_history_index = mini(_history_index + 1, _command_history.size())
		if _history_index == _command_history.size():
			input.clear()
		else:
			input.text = _command_history[_history_index]
			input.set_caret_column(input.text.length())

func _execute_command(cmd: String) -> void:
	var parts := cmd.split(" ", false)
	if parts.is_empty():
		return
	
	match parts[0].to_lower():
		"help":
			_log_line("""[color=white]Available commands:
  help                          — show this list
  list_sects                    — list all active sects
  list_chars [sect_id]          — list characters (optionally filter by sect)
  kill <char_id>                — mark a character as dead
  add_wealth <sect_id> <amount> — add wealth to a sect
  set_time <0-3>                — set time speed (0=paused … 3=superfast)
  print_event <event_id>        — dump event data from registry
  clear                         — clear this console[/color]""")
		
		"list_sects":
			for s_id in SimulationManager.sect_repo:
				var s: SectData = SimulationManager.sect_repo[s_id]
				_log_line("  [%s] %s  SS:%d" % [s.sect_id, s.sect_name, s.cached_sect_strength])
		
		"list_chars":
			var filter := parts[1] if parts.size() > 1 else ""
			for c_id in SimulationManager.character_repo:
				var c = SimulationManager.character_repo[c_id]
				if filter == "" or c.sect_id == filter:
					_log_line("  [%s] %s  sect:%s" % [c.char_id, c.get_full_name(), c.sect_id])
		
		"kill":
			if parts.size() < 2:
				_log_line("[color=red]Usage: kill <char_id>[/color]"); return
			var c = SimulationManager.get_character(parts[1])
			if c:
				c.life_state = Definitions.LifeState.DEAD
				_log_line("[color=orange]%s marked as DEAD.[/color]" % c.get_full_name())
			else:
				_log_line("[color=red]Character not found: %s[/color]" % parts[1])
		
		"add_wealth":
			if parts.size() < 3:
				_log_line("[color=red]Usage: add_wealth <sect_id> <amount>[/color]"); return
			var s = SimulationManager.get_sect(parts[1])
			if s:
				s.resources[Definitions.ResourceType.WEALTH] += int(parts[2])
				_log_line("[color=green]Added %s wealth to %s.[/color]" % [parts[2], s.sect_name])
			else:
				_log_line("[color=red]Sect not found: %s[/color]" % parts[1])
		
		"set_time":
			if parts.size() < 2:
				_log_line("[color=red]Usage: set_time <0-3>[/color]"); return
			TimeManager.set_time_speed(int(parts[1]))
			_log_line("[color=green]Time speed set to %s.[/color]" % parts[1])
		
		"print_event":
			if parts.size() < 2:
				_log_line("[color=red]Usage: print_event <event_id>[/color]"); return
			var ev = DataManager.events_registry.get(parts[1])
			if ev:
				_log_line(str(ev))
			else:
				_log_line("[color=red]Event not found: %s[/color]" % parts[1])
		
		"clear":
			($MarginContainer/VBox/TabContainer/Console/CommandOutput as RichTextLabel).clear()
		
		_:
			_log_line("[color=red]Unknown command: '%s'. Type 'help' for help.[/color]" % parts[0])

func _log_line(text: String) -> void:
	var output: RichTextLabel = $MarginContainer/VBox/TabContainer/Console/CommandOutput
	output.append_text(text + "\n")
	# Trim every 10 appends to avoid parsing the full text on every line
	_log_append_count += 1
	if _log_append_count >= 10:
		_log_append_count = 0
		if output.get_line_count() > MAX_LOG_LINES:
			var raw_lines := output.text.split("\n")
			raw_lines = raw_lines.slice(raw_lines.size() - MAX_LOG_LINES)
			output.text = "\n".join(raw_lines)

# --- STATS TAB ---

func _refresh_stats_tab() -> void:
	if not is_visible_in_tree():
		return
	var lbl: Label = $MarginContainer/VBox/TabContainer/Statistics/StatsLabel
	var lines: Array[String] = []
	lines.append("=== SIMULATION STATS ===")
	lines.append("Date:       %s" % TimeManager.get_date_string())
	lines.append("Speed:      %s" % TimeManager.Speed.keys()[TimeManager.current_speed])
	lines.append("")
	lines.append("Sects:      %d" % SimulationManager.sect_repo.size())
	lines.append("Characters: %d" % SimulationManager.character_repo.size())
	lines.append("")
	lines.append("Player char: %s" % GameManager.player_char_id)
	lines.append("Player sect: %s" % GameManager.player_sect_id)
	lines.append("")
	lines.append("Events loaded:    %d" % DataManager.events_registry.size())
	lines.append("Traits loaded:    %d" % DataManager.traits_registry.size())
	lines.append("Buildings loaded: %d" % DataManager.buildings_registry.size())
	lbl.text = "\n".join(lines)

# --- WORLD LOG TAB ---

func _refresh_log_tab() -> void:
	var lbl: RichTextLabel = $MarginContainer/VBox/TabContainer/WorldLog/LogLabel
	lbl.clear()
	var entries: Array = WorldLogManager.global_logs.slice(0, 50)
	for entry in entries:
		lbl.append_text("[%s] %s\n" % [entry.get("type", "?"), entry.get("message", "")])
