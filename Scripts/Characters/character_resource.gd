class_name Character extends Resource

@export_category("System Values")
## A character's unique ID, generated at spawn
@export var char_id: int

## The basic info of every character
@export_category("Character Info")
@export var char_fullname: String
@export var char_first_name: String
@export var char_last_name: String
@export var char_culture: Culture
@export var char_age: int = 5
@export var char_lifespan: int = 70
@export var potential: int = 1

@export_category("Character Personality")
@export var courage: int
@export var diligence: int
