extends Node

## Tracks high-level global events (wars, successions, sect destruction).

const MAX_LOGS = 1000

# We store dictionaries so the UI can easily filter or color-code by event type later.
# Format: {"date": "Year X...", "type": "war_declaration", "message": "..."}
var global_logs: Array[Dictionary] = []

signal log_added(log_entry: Dictionary)

func add_log(type: String, message: String) -> void:
	var entry = {
		"date": TimeManager.get_date_string(),
		"type": type,
		"message": message
	}
	
	global_logs.push_front(entry)
	
	if global_logs.size() > MAX_LOGS:
		global_logs.pop_back()
		
	log_added.emit(entry)

func clear_logs() -> void:
	global_logs.clear()
