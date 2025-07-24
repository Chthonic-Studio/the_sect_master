# TimeManager.gd
# Global time controller for The Sect Master.
# Handles calendar, time scale, pause, and emits signals for daily, period, and yearly ticks.
# Place in: res://scripts/managers/time_manager.gd
# Add as Autoload Singleton named "TimeManager" in Project Settings > Autoload.

extends Node

# === Calendar Definitions ===
const SEASONS = ["Early Spring", "Mid Spring", "Late Spring", "Early Summer", "Mid Summer", "Late Summer", "Early Autumn", "Mid Autumn", "Late Autumn", "Early Winter", "Mid Winter", "Late Winter"]
const PERIODS = ["Early", "Mid", "Late"]
const SEASONS_BASE = ["Spring", "Summer", "Autumn", "Winter"]

const PERIODS_PER_SEASON = 3
const SEASON_COUNT = 4
const PERIODS_PER_YEAR = PERIODS_PER_SEASON * SEASON_COUNT # 12
const DAYS_PER_PERIOD = 30
const LATE_PERIOD_EXTRA_DAY = 1

# === Starting Date ===
var start_year: int = 10500
var start_season: int = 0 # 0 = Spring
var start_period: int = 0 # 0 = Early
var start_day: int = 1

# === Time Variables ===
var year: int
var season: int # 0-3
var period: int # 0-2
var day: int

# === Speed Options ===
var day_length_sec: float = 1.0 # 1 day = 1 second at 1x
var speed_multipliers := [1.0, 3.0, 7.0]
var speed_index: int = 0 # 0=1x, 1=3x, 2=7x
var paused: bool = false

# === Timer ===
var _accum_time := 0.0

# === Signals ===
signal day_passed(year, season, period, day)
signal period_passed(year, season, period)
signal year_passed(year)
signal time_paused()
signal time_resumed()
signal speed_changed(speed_index, speed_multiplier)

# === Initialization ===
func _ready() -> void:
	reset_time()

func reset_time():
	year = start_year
	season = start_season
	period = start_period
	day = start_day
	_accum_time = 0.0

# === Main Tick ===
func _process(delta: float) -> void:
	if paused:
		return
	_accum_time += delta * speed_multipliers[speed_index]
	if _accum_time >= day_length_sec:
		_accum_time -= day_length_sec
		advance_day()

# === Advance Time Logic ===
func advance_day() -> void:
	day += 1
	var days_this_period = DAYS_PER_PERIOD
	if PERIODS[period] == "Late":
		days_this_period += LATE_PERIOD_EXTRA_DAY
	if day > days_this_period:
		day = 1
		advance_period()
	emit_signal("day_passed", year, season, period, day)

func advance_period() -> void:
	period += 1
	if period >= PERIODS_PER_SEASON:
		period = 0
		advance_season()
	emit_signal("period_passed", year, season, period)

func advance_season() -> void:
	season += 1
	if season >= SEASON_COUNT:
		season = 0
		advance_year()

func advance_year() -> void:
	year += 1
	emit_signal("year_passed", year)

# === Speed & Pause Controls ===
func set_speed(index: int):
	if index < 0 or index >= speed_multipliers.size():
		return
	var was_paused = paused
	speed_index = index
	if not paused:
		emit_signal("speed_changed", speed_index, speed_multipliers[speed_index])

func pause_time():
	if not paused:
		paused = true
		emit_signal("time_paused")

func resume_time():
	if paused:
		paused = false
		emit_signal("time_resumed")

func toggle_pause():
	if paused:
		resume_time()
	else:
		pause_time()

func is_paused() -> bool:
	return paused

# === Date Formatting ===
func get_date_string() -> String:
	var season_name = SEASONS_BASE[season]
	var period_name = PERIODS[period]
	return "%s %s, Day %d, Year %d" % [period_name, season_name, day, year]

func get_full_season_string() -> String:
	# E.g., "Late Spring"
	return "%s %s" % [PERIODS[period], SEASONS_BASE[season]]
