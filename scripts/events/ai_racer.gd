# ai_racer.gd
# Controlador de Inteligencia Artificial que conduce un vehículo físico a lo largo de un Path3D.
class_name AIRacer
extends Node3D

@export_category("Referencias")
## El nodo del vehículo físico que controlará esta IA (de tipo Vehicle del addon gevp).
@export var vehicle_node: RigidBody3D
## La ruta (Path3D) que representa la línea de carrera en el circuito.
@export var path_node: Path3D

@export_category("Parámetros de Conducción")
## Distancia de mira hacia adelante (en metros) para calcular la dirección.
@export var look_ahead_distance: float = 12.0
## Velocidad máxima en rectas (m/s). 27.7 m/s es aprox. 100 km/h.
@export var max_speed: float = 35.0
## Velocidad mínima permitida en curvas cerradas (m/s).
@export var min_speed_in_curves: float = 12.0
## Sensibilidad de la dirección (multiplicador del ángulo de giro).
@export var steer_sensitivity: float = 2.5
## Dificultad (de 0.0 a 1.0). Reduce la velocidad máxima y el tiempo de reacción.
@export var difficulty: float = 0.8

# Estado interno
var path_follower: PathFollow3D
var curve: Curve3D
var last_safe_position: Vector3
var last_safe_transform: Transform3D

# Variables de anti-bloqueo (stuck prevention)
var stuck_timer: float = 0.0
var stuck_threshold_time: float = 3.0 # Segundos antes de reaparecer

func _ready() -> void:
	if not path_node:
		push_error("AIRacer: No se ha asignado un nodo Path3D.")
		set_physics_process(false)
		return
		
	curve = path_node.curve
	
	# Crear dinámicamente un PathFollow3D para seguir la trayectoria
	path_follower = PathFollow3D.new()
	path_node.add_child(path_follower)
	path_follower.loop = true
	
	# Guardar posición inicial de seguridad
	if vehicle_node:
		last_safe_position = vehicle_node.global_position
		last_safe_transform = vehicle_node.global_transform
		
		# Asegurar que la IA está en el grupo correcto
		vehicle_node.add_to_group("ai")

func _physics_process(delta: float) -> void:
	if not vehicle_node or not path_follower:
		return
		
	var car_pos = vehicle_node.global_position
	
	# 1. Encontrar el punto más cercano de la curva al vehículo (en coordenadas locales del Path3D)
	var local_car_pos = path_node.to_local(car_pos)
	var closest_offset = curve.get_closest_offset(local_car_pos)
	
	# 2. Calcular la posición objetivo un poco más adelante en la trayectoria (Pure Pursuit)
	var speed_factor = vehicle_node.linear_velocity.length() * 0.25
	var dynamic_look_ahead = look_ahead_distance + speed_factor
	path_follower.progress = closest_offset + dynamic_look_ahead
	var target_pos = path_follower.global_position
	
	# 3. Calcular la dirección local hacia el objetivo
	var local_target = vehicle_node.global_transform.affine_inverse() * target_pos
	
	# En Godot, el eje -Z es hacia adelante. Calculamos el ángulo en el plano XZ.
	var angle_to_target = atan2(-local_target.x, -local_target.z)
	
	# 4. Calcular dirección (steering)
	var steer_input = clamp(angle_to_target * steer_sensitivity, -1.0, 1.0)
	vehicle_node.steering_input = steer_input
	
	# 5. Ajustar velocidad en función de la curvatura de la pista
	# Comprobar la dirección de un punto mucho más adelante (anticipación de curva)
	path_follower.progress = closest_offset + dynamic_look_ahead * 2.5
	var far_target = path_follower.global_position
	var local_far_target = vehicle_node.global_transform.affine_inverse() * far_target
	var far_angle = abs(atan2(-local_far_target.x, -local_far_target.z))
	
	# Limitar velocidad según la dificultad y la curvatura detectada
	var current_max_speed = max_speed * (0.6 + difficulty * 0.4)
	var target_speed = current_max_speed
	
	if far_angle > 0.15: # Ángulo significativo adelante (curva)
		# Escalar la reducción de velocidad basada en la agresividad del ángulo
		var curvature_factor = clamp(far_angle / 1.0, 0.0, 1.0)
		target_speed = lerp(current_max_speed, min_speed_in_curves, curvature_factor)
		
	# 6. Controlar Acelerador y Freno
	var current_speed = vehicle_node.linear_velocity.length()
	
	if current_speed < target_speed:
		# Acelerar
		vehicle_node.throttle_input = 1.0
		vehicle_node.brake_input = 0.0
	else:
		# Dejar de acelerar y aplicar freno si va muy pasado
		vehicle_node.throttle_input = 0.0
		if current_speed > target_speed + 1.5:
			vehicle_node.brake_input = 0.6
		else:
			vehicle_node.brake_input = 0.0
			
	# 7. Prevención de atascos (Anti-Stuck)
	if current_speed < 0.8 and vehicle_node.throttle_input > 0.5:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold_time:
			_reset_to_safety()
	else:
		stuck_timer = 0.0

## Actualiza la posición segura cuando la IA cruza un checkpoint (llamado desde EventRunner o de forma local).
func update_safe_position(pos: Vector3, rot_basis: Basis) -> void:
	last_safe_position = pos
	last_safe_transform = Transform3D(rot_basis, pos)

# Recoloca el vehículo si se ha salido de la pista o volcado
func _reset_to_safety() -> void:
	stuck_timer = 0.0
	
	# Detener fuerzas físicas
	vehicle_node.linear_velocity = Vector3.ZERO
	vehicle_node.angular_velocity = Vector3.ZERO
	
	# Teletransportar ligeramente elevado para no atascarse con el suelo
	var reset_transform = last_safe_transform
	reset_transform.origin += Vector3.UP * 0.5
	vehicle_node.global_transform = reset_transform
