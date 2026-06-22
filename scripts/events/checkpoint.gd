# checkpoint.gd
# Detecta el paso de los vehículos por un punto de control y actualiza sus efectos visuales.
class_name Checkpoint
extends Area3D

## Emitida cuando un vehículo cruza el checkpoint.
signal vehicle_passed(vehicle: Node3D, checkpoint: Checkpoint)

## Identificador único del checkpoint en el circuito.
@export var checkpoint_id: int = 0
## Color cuando el checkpoint es el siguiente objetivo activo.
@export var active_color: Color = Color(0, 0.8, 1, 1) # Cyan brillante
## Color cuando el checkpoint no es el objetivo activo actual o ya se ha pasado.
@export var inactive_color: Color = Color(1, 0, 0.2, 1) # Rojo apagado

@onready var mesh_indicator: MeshInstance3D = $MeshIndicator

## Estado de actividad del checkpoint (determina si es el siguiente que el jugador debe cruzar).
var is_active: bool = false:
	set(val):
		is_active = val
		_update_visuals()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _on_body_entered(body: Node3D) -> void:
	# Comprobar si el cuerpo es un vehículo (detecta si está en el grupo de jugador o IA, o tiene velocidad)
	if body.is_in_group("player") or body.is_in_group("ai") or body.has_method("get_speed_kmh") or body.has_method("get_speed"):
		vehicle_passed.emit(body, self)

func _update_visuals() -> void:
	if not is_inside_tree() or not mesh_indicator:
		return
		
	# Solo hacer visible el checkpoint si es el siguiente objetivo activo del jugador
	mesh_indicator.visible = is_active
	
	# Duplicar el material para evitar cambiar el de todas las instancias del disco
	var mat = mesh_indicator.get_active_material(0)
	if mat:
		var new_mat = mat.duplicate() as StandardMaterial3D
		if new_mat:
			new_mat.albedo_color = active_color
			new_mat.emission_enabled = true
			new_mat.emission = active_color
			new_mat.emission_energy_multiplier = 4.0 # Brillo intenso para guiar al jugador
			mesh_indicator.material_override = new_mat

