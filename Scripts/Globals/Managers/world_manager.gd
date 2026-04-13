extends Node

const TARGET_WORLD_POPULATION: int = 3000
const MAX_YEARLY_RECOVERY_RATE: float = 0.05 # The world only heals 5% of its max population per year

# Stores an array of days (1-360) on which a character should spawn this year.
var _scheduled_spawns_this_year: Array[int] = []
# Stores spawns as Dict[Day_Of_Year(int) : Spawn_Count(int)]
var _spawns_by_day: Dictionary = {}

func _ready() -> void:
	TimeManager.year_passed.connect(_on_year_passed)
	TimeManager.day_passed.connect(_on_day_passed)

func _on_year_passed(_year: int) -> void:
	_spawns_by_day.clear()
	var current_pop = SimulationManager.character_repo.size()
	var deficit = TARGET_WORLD_POPULATION - current_pop
	
	if deficit <= 0:
		return
		
	var max_spawns = int(TARGET_WORLD_POPULATION * MAX_YEARLY_RECOVERY_RATE)
	var spawns_to_schedule = mini(deficit, max_spawns)
	
	for i in range(spawns_to_schedule):
		var day = randi_range(1, TimeManager.DAYS_PER_MONTH * TimeManager.MONTHS_PER_YEAR)
		# Increment the spawn count for this specific day
		_spawns_by_day[day] = _spawns_by_day.get(day, 0) + 1

func _on_day_passed(_day_of_year: int) -> void:
	var current_day_of_year = ((TimeManager.month - 1) * TimeManager.DAYS_PER_MONTH) + TimeManager.day
	
	if _spawns_by_day.has(current_day_of_year):
		var spawn_count = _spawns_by_day[current_day_of_year]
		for i in range(spawn_count):
			CharacterGenerator.create_character(CharacterGenerator.GenerationContext.REPOPULATE)
		# O(1) removal, no array shifting
		_spawns_by_day.erase(current_day_of_year)
