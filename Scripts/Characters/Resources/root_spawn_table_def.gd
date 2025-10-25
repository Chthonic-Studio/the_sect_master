class_name RootSpawnTableDef extends Resource

@export_category("Spiritual Root Spawn Table")
@export var entries: Array[RootSpawnEntry]

# Use a local RNG for the selection (seeded per-resource lifetime)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_inited: bool = false

func _ensure_rng() -> void:
	if not _rng_inited:
		_rng.randomize()
		_rng_inited = true

func get_random_root() -> SpiritualRoot:
	_ensure_rng()
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.spawn_weight

	if total_weight <= 0:
		push_error("Spawn table has no weight or entries.")
		return null

	var random_point = _rng.randf() * total_weight
	var current_weight = 0.0

	for entry in entries:
		current_weight += entry.spawn_weight
		if random_point < current_weight:
			return entry.root

	# Fallback to last entry
	if entries.size() > 0:
		return entries.back().root
	return null
