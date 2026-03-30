class_name Blackboard extends RefCounted

## A centralized registry for entities to advertise availability and claim targets.
## This is transient data, NOT saved/loaded. Entities must re-advertise their availability.

var available_entities: Dictionary = {} # Maps tag (String) -> Array[String]
var reserved_entities: Dictionary = {}  # Maps target_id (String) -> claimer_id (String)

## Entities call this when they are idle and available for interactions
func advertise(tag: String, entity_id: String) -> void:
	if not available_entities.has(tag):
		available_entities[tag] = []
	if not available_entities[tag].has(entity_id):
		available_entities[tag].append(entity_id)

## Entities call this when they are no longer available
func withdraw_advertisement(tag: String, entity_id: String) -> void:
	if available_entities.has(tag):
		available_entities[tag].erase(entity_id)

## Actions call this to securely grab a target and prevent others from using it.
func claim_target(tag: String, claimer_id: String) -> String:
	if not available_entities.has(tag) or available_entities[tag].is_empty():
		return "" 
		
	var target_id = available_entities[tag].pop_back()
	reserved_entities[target_id] = claimer_id
	return target_id

## Actions call this when they finish, cancel, or abort.
func release_target(tag: String, target_id: String) -> void:
	if reserved_entities.has(target_id):
		reserved_entities.erase(target_id)
		advertise(tag, target_id) # Put them back in the pool
