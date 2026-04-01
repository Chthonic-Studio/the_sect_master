extends Node

## Systems should connect to the signals (e.g., TimeManager.day_passed.connect(_on_day_passed))
## Use set_time_speed() to control the simulation flow from UI.

# --- SIGNALS ---
signal day_passed(day: int)
signal month_passed(month: int)
signal year_passed(year: int)
signal speed_changed(new_speed: int)

# --- ENUMS & CONSTANTS ---
enum Speed {
	PAUSED = 0,
	NORMAL = 1,
	FAST = 2,
	SUPER_FAST = 3
}

# The calendar definition (Standardized to 360 days for clean simulation math)
const DAYS_PER_MONTH = 30
const MONTHS_PER_YEAR = 12

# How many real-world seconds equal 1 in-game DAY at NORMAL speed.
# Adjust this to change the baseline pacing of the game.
const SECONDS_PER_DAY = 3.0 

# Prevent "Death Spirals" where a massive lag spike causes the engine 
# to try and process hundreds of days in a single frame, crashing the game.
const MAX_TICKS_PER_FRAME = 30 

var _epoch_day: int = 0

# --- STATE ---
var current_speed: Speed = Speed.PAUSED

var year: int = 740
var month: int = 1
var day: int = 1

var _time_accumulator: float = 0.0

# --- CORE LOOP ---
func _process(delta: float) -> void:
	if current_speed == Speed.PAUSED:
		return
		
	# Accumulate real time modified by our current game speed
	_time_accumulator += delta * _get_speed_multiplier()
	
	var ticks_processed = 0
	# While we have accumulated enough time for an in-game day, tick the simulation
	while _time_accumulator >= SECONDS_PER_DAY:
		_time_accumulator -= SECONDS_PER_DAY
		ticks_processed += 1
		
		_advance_day()
		
		# Death-spiral prevention
		if ticks_processed >= MAX_TICKS_PER_FRAME:
			_time_accumulator = 0.0 # Discard overflow time to save the CPU
			printerr("TimeManager: CPU overloaded, dropping simulation ticks!")
			break

# --- TIME ADVANCEMENT LOGIC ---
func _advance_day() -> void:
	_epoch_day += 1
	
	day += 1
	if day > DAYS_PER_MONTH:
		day = 1
		_advance_month()
		
	day_passed.emit(day)

func _advance_month() -> void:
	month += 1
	if month > MONTHS_PER_YEAR:
		month = 1
		_advance_year()
		
	month_passed.emit(month)

func _advance_year() -> void:
	year += 1
	year_passed.emit(year)

# --- CONTROLS ---
func set_time_speed(new_speed: Speed) -> void:
	if current_speed != new_speed:
		current_speed = new_speed
		speed_changed.emit(current_speed)

func toggle_pause() -> void:
	if current_speed == Speed.PAUSED:
		set_time_speed(Speed.NORMAL)
	else:
		set_time_speed(Speed.PAUSED)

func _get_speed_multiplier() -> float:
	match current_speed:
		Speed.NORMAL: return 1.0
		Speed.FAST: return 3.0     
		Speed.SUPER_FAST: return 7.0 
		_: return 0.0

# --- UTILITY ---
func get_date_string() -> String:
	return "Year %d, Month %d, Day %d" % [year, month, day]

# Returns absolute time elapsed for calculating expiration dates of buffs/debuffs.
func get_total_days_elapsed() -> int:
	return _epoch_day
