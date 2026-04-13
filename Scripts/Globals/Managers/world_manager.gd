extends Node

const TARGET_WORLD_POPULATION: int = 3000
const MAX_YEARLY_RECOVERY_RATE: float = 0.05 # The world only heals 5% of its max population per year

# Stores an array of days (1-360) on which a character should spawn this year.
var _scheduled_spawns_this_year: Array[int] = []

func _ready() -> void:
	TimeManager.year_passed.connect(_on_year_passed)
	TimeManager.day_passed.connect(_on_day_passed)

## Evaluates the demographic deficit and schedules repopulation events for the upcoming year.
func _on_year_passed(_year: int) -> void:
	_scheduled_spawns_this_year.clear()
	
	var current_pop = SimulationManager.character_repo.size()
	var deficit = TARGET_WORLD_POPULATION - current_pop
	
	if deficit <= 0:
		return
		
	# Cap the recovery to simulate the long-lasting devastation of war
	var max_spawns = int(TARGET_WORLD_POPULATION * MAX_YEARLY_RECOVERY_RATE)
	var spawns_to_schedule = mini(deficit, max_spawns)
	
	# Randomly distribute these spawns across the 360-day calendar
	for i in range(spawns_to_schedule):
		_scheduled_spawns_this_year.append(randi_range(1, TimeManager.DAYS_PER_MONTH * TimeManager.MONTHS_PER_YEAR))
		
	# Optional: Sort them so we can pop them off the front, though finding/erasing is fine for small arrays
	_scheduled_spawns_this_year.sort()

## Evaluates if any wanderers or peasants are scheduled to "arrive" in the world today.
func _on_day_passed(_day_of_year: int) -> void:
	# Calculate the absolute day of the year (1-360)
	var current_day_of_year = ((TimeManager.month - 1) * TimeManager.DAYS_PER_MONTH) + TimeManager.day
	
	# We use a while loop because multiple characters might be scheduled for the same day
	var _spawned_today = 0
	while _scheduled_spawns_this_year.has(current_day_of_year):
		_scheduled_spawns_this_year.erase(current_day_of_year)
		_spawned_today += 1
		
		# Context determines they are a non-martial peasant/worker
		CharacterGenerator.create_character(CharacterGenerator.GenerationContext.REPOPULATE)
