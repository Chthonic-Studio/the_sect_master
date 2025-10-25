extends Node

@export var name_pool: NamePoolDef = preload("res://Resources/Characters/name_pool.tres")
@export var root_spawn_table: RootSpawnTableDef = preload("res://Resources/Characters/root_table_def.tres")
@export var character_scene: PackedScene = preload("res://Scenes/character.tscn")

func _ready() -> void:
	pass
