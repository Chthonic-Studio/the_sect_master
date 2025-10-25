class_name NamePoolDef extends Resource

@export_category("Name Pools")
@export_multiline var last_names: String = "Li,Wang,Zhang,Liu,Chen,Yang,Huang,Zhao" # Comma-separated list

@export_category("First Names")
@export_multiline var male_first_names: String = "Wei,Jian,Lei,Bo,Fan,Hao,Min,Quan"
@export_multiline var female_first_names: String = "Mei,Lin,Hua,Ying,Xiao,Jing,Rong,Fen"

# Local RNG to avoid using global helpers directly; seeded on first use
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_inited: bool = false

func _ensure_rng() -> void:
	if not _rng_inited:
		_rng.randomize()
		_rng_inited = true

# --- Internal Functions for Selection ---
func _get_random_element(list_string: String) -> String:
	_ensure_rng()
	var elements: Array = list_string.split(",", false)
	if elements.is_empty():
		return ""
	var idx: int = _rng.randi_range(0, elements.size() - 1)
	return elements[idx].strip_edges()

func get_random_last_name() -> String:
	return _get_random_element(last_names)

# Changed signature: accept an int (CharacterData.Gender) so callers can pass CharacterData.Gender values.
# This avoids referencing CharacterDefinition.Gender which doesn't exist in the repo.
func get_random_first_name(gender: int) -> String:
	match gender:
		CharacterData.Gender.FEMALE:
			return _get_random_element(female_first_names)
		CharacterData.Gender.MALE:
			return _get_random_element(male_first_names)
		_:
			return _get_random_element(male_first_names)
