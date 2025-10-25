class_name TraitPoolDef extends Resource

@export var traits: Array[CharacterTrait] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _inited: bool = false

func _ensure_rng() -> void:
	if not _inited:
		_rng.randomize()
		_inited = true

# Returns 'count' unique random trait resources (or fewer if pool smaller)
func get_random_traits(count: int = 3) -> Array:
	_ensure_rng()
	var out: Array = []
	if traits.is_empty():
		return out
	var indices := []
	for i in traits.size():
		indices.append(i)
	# Fisher-Yates-like selection for uniqueness
	for i in range(min(count, indices.size())):
		var pick_idx = _rng.randi_range(i, indices.size() - 1)
		var tmp = indices[i]
		indices[i] = indices[pick_idx]
		indices[pick_idx] = tmp
	for j in range(min(count, indices.size())):
		out.append(traits[indices[j]])
	return out
