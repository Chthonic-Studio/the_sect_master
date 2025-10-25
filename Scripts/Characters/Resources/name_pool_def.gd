class_name NamePoolDef extends Resource

@export_category("Name Pools")

@export_multiline var last_names: String = "Li,Wang,Zhang,Liu,Chen,Yang,Huang,Zhao" # Comma-separated list

@export_category("First Names")

@export_multiline var male_first_names: String = "Wei,Jian,Lei,Bo,Fan,Hao,Min,Quan" ## Comma-separated list
@export_multiline var female_first_names: String = "Mei,Lin,Hua,Ying,Xiao,Jing,Rong,Fen" ## Comma-separated list

# --- Internal Functions for Selection ---

## Gets a random element from a comma-separated string list
func _get_random_element(list_string: String) -> String:
	var elements = list_string.split(",", false) # split, avoiding empty strings
	if elements.is_empty():
		return ""
	# Trim whitespace and select a random element
	return elements[randi() % elements.size()].strip_edges()

func get_random_last_name() -> String:
	return _get_random_element(last_names)

func get_random_first_name(gender: CharacterDefinition.Gender) -> String:
	match gender:
		CharacterDefinition.Gender.FEMALE:
			return _get_random_element(female_first_names)
		CharacterDefinition.Gender.MALE:
			return _get_random_element(male_first_names)
		_:
			return "Error" # Fallback
