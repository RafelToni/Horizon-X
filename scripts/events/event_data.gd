# event_data.gd
# Recurso de Godot para definir los datos básicos y recompensas de cada evento.
class_name EventData
extends Resource

enum EventType { ROAD_RACE, STREET_RACE, DIRT, DRAG, DRIFT_ZONE }

@export var event_name: String = "Carrera de Prototipo"
@export var event_type: EventType = EventType.ROAD_RACE
@export var laps: int = 3
@export var reward_credits: int = 5000
@export var reward_fans: int = 500
