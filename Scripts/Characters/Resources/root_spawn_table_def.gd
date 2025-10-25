class_name RootSpawnTableDef extends Resource

@export_category("Spiritual Root Spawn Table")
@export var entries: Array[RootSpawnEntry]

func get_random_root() -> SpiritualRoot:
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.spawn_weight

	if total_weight <= 0:
		push_error("Spawn table has no weight or entries.")
		return null

	var random_point = randf() * total_weight
	var current_weight = 0.0

	for entry in entries:
		current_weight += entry.spawn_weight
		if random_point < current_weight:
			return entry.root

	# Fallback to last entry
	if entries.size() > 0:
		return entries.back().root
	return null
